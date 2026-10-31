"""The blocking pool: worker threads that run blocking functions for IO.blocking and IO.interruptible.

After Cats Effect's blocking execution context and Erlang's dirty I/O
schedulers. A pool owns a queue of jobs and up to `max_workers` OS threads.
Workers start on demand, take jobs in queue order, are reused while jobs keep
arriving, and retire after `idle_timeout` without work. A job runs one owned
function and completes the submitting fiber's `Completion` with its outcome;
the run loop never runs on a worker.

Ownership. Copies of a `BlockingPool` share one pool, which lives as long as
its copies. A root holds a copy: the one in its `IORuntimeConfig`, installed
when the root is created, or a private pool created on the root's first
blocking call (see the root's hook below).
Finishing a root waits for its in-flight calls (their callers wait for them
anyway, so only the worker's last steps remain), then drops its copy. Dropping
the last copy closes the pool: every queued job runs, then the workers stop and
are joined; on one of the pool's own workers, that worker is detached instead.
Each worker body holds a reference to the pool's core until it returns, and
the worker list holds none, so a detached worker releases the core last.

Cross-thread rules. The pool is reached from the submitting threads and from
every worker, so every method takes immutable `self`, and its atomics live in
their own allocation behind a pointer (see the development guide's "Never
borrow a shared object mutably from two threads"). The job queue is S4's
`_ExternalQueue`; the worker list is a `_Cell` locked with the shared
`_lock_cell`.

Parking. Each worker owns an S2 `_Poller` and parks in `poll(idle_timeout)`.
An idle worker publishes its `_Interrupter` on the idle list (a `_Cell` locked
with `_lock_cell`) before re-reading the queue; a submitter pushes its job, then
takes one entry off the idle list and interrupts it. Both steps pass through the
idle list's lock, so either the submitter finds the worker's entry and wakes
it, or the worker's re-read, which follows its publication, finds the job. A
woken worker removes its own entry, if still there, and re-reads the queue; an
interrupt that finds no job, or one left over from an interruptible call, is a
spurious wake. A worker running a call passes its poller to the call, so an
`Interruption` waits in it too.

Memory ordering of each atomic operation:

- `live` (started, not retired workers) and the worker list change only under
  the worker-list lock, which orders spawning against retiring: a retiring
  worker re-reads the queue under that lock, and a submitter that found no
  idle worker decides whether to start one under the same lock. Loads outside
  the lock are RELAXED hints for tests.
- `started` counts every worker ever started; RELAXED, a test hint.
- `closed` is stored SEQUENTIAL by `close`, which then takes the idle list's
  lock and interrupts every parked worker; workers load it ACQUIRE after
  publishing themselves on the idle list, so a worker either sees the flag or
  is interrupted. A worker that sees it with an empty queue exits.
- A root's in-flight count (`_Calls`) is incremented RELAXED before the job is
  published (the queue lock orders it), and decremented RELEASE by the worker
  after its last use of the job; the root's finish loads it ACQUIRE, so
  everything the worker did happens before the root returns.
"""
from std.atomic import Atomic, Ordering, fence
from std.memory import ArcPointer, OwnedPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import sleep, monotonic
from fp._internal.cells import _Cell, _lock_cell
from fp._internal.erased import _Erased
from fp._internal.os import OSThread, threads_supported
from fp._internal.time import Duration
from fp._internal.waking import _Scheduler
from ..polling import _Poller, _Interrupter
from .external_queue import _ExternalQueue
from .random import _Random


comptime _DEFAULT_MAX_WORKERS = 64
comptime _DEFAULT_IDLE_SECONDS = 60


# ===------------------------------------------------------------------=== #
# Per-root in-flight calls
# ===------------------------------------------------------------------=== #


struct _PaddedCount(Movable):
    var value: Atomic[Int]
    var _padding: Array[Int, 7]

    def __init__(out self):
        self.value = Atomic(0)
        self._padding = Array[Int, 7](fill=0)


struct _Calls(Copyable):
    """A root's blocking calls between submission and the worker's last step; copies share it."""
    var _count: ArcPointer[_PaddedCount]

    def __init__(out self):
        self._count = ArcPointer(_PaddedCount())

    def begin(self):
        _ = self._count[].value.fetch_add[ordering=Ordering.RELAXED](1)

    def end(self):
        _ = self._count[].value.fetch_sub[ordering=Ordering.RELEASE](1)

    def in_flight(self) -> Int:
        return self._count[].value.load[ordering=Ordering.ACQUIRE]()

    def wait(self):
        """Wait until every call has finished on its worker.

        Called when a root finishes. Each caller already waited for its call's
        completion, so only the worker's final drops remain: yielding is enough.
        """
        while self.in_flight() != 0:
            sleep(0.0)


# ===------------------------------------------------------------------=== #
# Jobs
# ===------------------------------------------------------------------=== #


struct _WorkerContext(Copyable):
    """What a call receives from the worker running it: the worker's poller and its interrupter.

    The poller belongs to the worker thread; only a call running on that
    worker waits in it. The interrupter may be published to other threads.
    """
    var poller: Pointer[_Poller, MutUntrackedOrigin]
    var interrupter: _Interrupter

    def __init__(out self, poller: Pointer[_Poller, MutUntrackedOrigin], var interrupter: _Interrupter):
        self.poller = poller
        self.interrupter = interrupter^


comptime _RunJob = def(var _Erased, _WorkerContext) thin
"""Run an erased call on a worker: call the function and complete its fiber."""


struct _Job(Movable):
    """One call: its erased body, the thin function that runs it, and its root's count."""
    var body: _Erased
    var run: _RunJob
    var calls: _Calls

    def __init__(out self, var body: _Erased, run: _RunJob, calls: _Calls):
        self.body = body^
        self.run = run
        self.calls = calls.copy()

    def execute(deinit self, worker: _WorkerContext):
        """Run the call; the root's count drops after the worker's last use of it."""
        self.run(self.body^, worker)
        self.calls.end()


# ===------------------------------------------------------------------=== #
# The pool
# ===------------------------------------------------------------------=== #


struct _Words(Movable):
    """The pool's atomics, each on its own cache line."""
    var live: Atomic[Int]
    var _pad1: Array[Int, 7]
    var started: Atomic[Int]
    var _pad2: Array[Int, 7]
    var closed: Atomic[UInt8]
    var _pad3: Array[Int, 7]

    def __init__(out self):
        self.live = Atomic(0)
        self._pad1 = Array[Int, 7](fill=0)
        self.started = Atomic(0)
        self._pad2 = Array[Int, 7](fill=0)
        self.closed = Atomic(UInt8(0))
        self._pad3 = Array[Int, 7](fill=0)


struct _WorkerState(Movable):
    """What a worker thread receives: its pool and its identity."""
    # Taken by the body when it starts, so the worker list holds no reference
    # to its own pool; the body keeps the pool alive until it returns.
    var core: Optional[ArcPointer[_PoolCore]]
    var id: Int

    def __init__(out self, var core: ArcPointer[_PoolCore], id: Int):
        self.core = Optional(core^)
        self.id = id


struct _Worker(Movable):
    var id: Int
    var thread: OSThread[_WorkerState]

    def __init__(out self, id: Int, var thread: OSThread[_WorkerState]):
        self.id = id
        self.thread = thread^

    def detach(deinit self):
        _ = self.thread^.detach()


struct _Workers(Movable):
    """Started workers not yet joined, and the identities of those that exited."""
    var running: List[_Worker]
    var exited: List[Int]
    var next_id: Int

    def __init__(out self):
        self.running = List[_Worker]()
        self.exited = List[Int]()
        self.next_id = 0

    def take_exited(mut self) -> List[_Worker]:
        """Remove the workers that exited, to be joined outside the lock."""
        var joined = List[_Worker]()
        for id in self.exited:
            for i in range(len(self.running)):
                if self.running[i].id == id:
                    joined.append(self.running.pop(i))
                    break
        self.exited.clear()
        return joined^

    def take_all(mut self) -> List[_Worker]:
        var all = List[_Worker]()
        while len(self.running):
            all.append(self.running.pop())
        self.exited.clear()
        return all^


def _seed() -> UInt64:
    return UInt64(monotonic())


struct _Retirement(Movable):
    var job: Optional[_Job]
    var retired: Bool

    def __init__(out self, var job: Optional[_Job], retired: Bool):
        self.job = job^
        self.retired = retired


struct _Parked(Copyable):
    var id: Int
    var interrupter: _Interrupter

    def __init__(out self, id: Int, interrupter: _Interrupter):
        self.id = id
        self.interrupter = interrupter.copy()


struct _PoolCore(Movable):
    """The shared state of one pool: reached from submitters and workers, always immutably."""
    var queue: _ExternalQueue[_Job]
    var _words: Pointer[_Words, MutUntrackedOrigin]
    var _workers: Pointer[_Cell[_Workers], MutUntrackedOrigin]
    var _idle: Pointer[_Cell[List[_Parked]], MutUntrackedOrigin]
    var max_workers: Int
    var idle_nanoseconds: Int

    def __init__(out self, max_workers: Int, idle_nanoseconds: Int):
        self.queue = _ExternalQueue[_Job](4)
        self._words = unsafe_alloc[_Words](1, alignment=64)
        self._words.unsafe_write(_Words())
        self._workers = unsafe_alloc[_Cell[_Workers]](1, alignment=64)
        self._workers.unsafe_write(_Cell(Atomic(UInt8(0)), Optional(_Workers())))
        self._idle = unsafe_alloc[_Cell[List[_Parked]]](1, alignment=64)
        self._idle.unsafe_write(_Cell(Atomic(UInt8(0)), Optional(List[_Parked]())))
        self.max_workers = max_workers
        self.idle_nanoseconds = idle_nanoseconds

    def __deinit__(deinit self):
        # Closed, and every worker body that held a reference has returned.
        self._words.unsafe_deinit_pointee()
        self._words.unsafe_free()
        self._workers.unsafe_deinit_pointee()
        self._workers.unsafe_free()
        self._idle.unsafe_deinit_pointee()
        self._idle.unsafe_free()

    @always_inline
    def words(self) -> ref[MutUntrackedOrigin] _Words:
        return self._words[]

    @always_inline
    def workers(self) -> ref[MutUntrackedOrigin] _Cell[_Workers]:
        return self._workers[]

    def closed(self) -> Bool:
        return self.words().closed.load[ordering=Ordering.ACQUIRE]() != 0

    @always_inline
    def idle(self) -> ref[MutUntrackedOrigin] _Cell[List[_Parked]]:
        return self._idle[]

    # Parking.

    def _park(self, id: Int, interrupter: _Interrupter):
        """Publish an idle worker, before it re-reads the queue."""
        var guard = _lock_cell(self.idle())
        guard.value().append(_Parked(id, interrupter))
        _ = guard^

    def _unpark(self, id: Int) -> Bool:
        """Withdraw a worker's entry; False when a submitter or close took it."""
        var guard = _lock_cell(self.idle())
        ref parked = guard.value()
        var found = False
        for i in range(len(parked)):
            if parked[i].id == id:
                _ = parked.pop(i)
                found = True
                break
        _ = guard^
        return found

    def _claim(self) -> Optional[_Interrupter]:
        """Take the most recently parked worker, which is the warmest."""
        var guard = _lock_cell(self.idle())
        ref parked = guard.value()
        var claimed = Optional[_Interrupter]()
        if len(parked):
            claimed = Optional(parked.pop().interrupter.copy())
        _ = guard^
        return claimed^

    def _wake_all(self):
        var guard = _lock_cell(self.idle())
        var parked = guard.value().copy()
        guard.value().clear()
        _ = guard^
        for entry in parked:
            entry.interrupter.interrupt()

    def _try_retire(self, id: Int, mut random: _Random) -> _Retirement:
        """Leave the pool unless a job arrived; the worker is not parked.

        Decided under the worker-list lock, which submitters take to decide
        whether to start a worker, so a job is never left with no worker to run
        it.
        """
        var guard = _lock_cell(self.workers())
        var job = self.queue.pop(random)
        if job:
            # Mojo destroys a value after its last use: keep the lock held to here.
            _ = guard^
            return _Retirement(job^, False)
        _ = self.words().live.fetch_sub[ordering=Ordering.RELAXED](1)
        guard.value().exited.append(id)
        _ = guard^
        return _Retirement(None, True)

    def live(self) -> Int:
        return self.words().live.load[ordering=Ordering.RELAXED]()

    def started(self) -> Int:
        return self.words().started.load[ordering=Ordering.RELAXED]()

    def close(self):
        """Run every queued job, then stop and join every worker.

        Called when the last handle is dropped. On one of the pool's own
        workers, which cannot join itself, that worker is detached instead: it
        finishes its job, sees the pool closed, and exits on its own, releasing
        the pool last.
        """
        self.words().closed.store[ordering=Ordering.SEQUENTIAL](UInt8(1))
        self._wake_all()
        var all: List[_Worker]
        var guard = _lock_cell(self.workers())
        all = guard.value().take_all()
        _ = guard^
        # Each worker drains the queue, sees the flag and exits.
        while len(all):
            var worker = all.pop()
            if worker.thread.is_current():
                worker^.detach()
            else:
                _ = worker^


def _submit(core: ArcPointer[_PoolCore], var job: _Job):
    """Queue a job and make sure a worker will take it.

    Claims an idle worker, else starts one when fewer than the maximum run;
    at the maximum, the job waits for the first worker to finish its call.
    """
    var random = _Random(_seed())
    core[].queue.push(job^, random)
    var claimed = core[]._claim()
    if claimed:
        # The claimed worker finds the job on its next queue read.
        claimed.value().interrupt()
        return
    var joined: List[_Worker]
    var guard = _lock_cell(core[].workers())
    ref workers = guard.value()
    joined = workers.take_exited()
    if core[].words().live.load[ordering=Ordering.RELAXED]() < core[].max_workers:
        var id = workers.next_id
        workers.next_id += 1
        try:
            var thread = OSThread(ArcPointer(_WorkerState(core.copy(), id)), _worker_main)
            workers.running.append(_Worker(id, thread^))
            _ = core[].words().live.fetch_add[ordering=Ordering.RELAXED](1)
            _ = core[].words().started.fetch_add[ordering=Ordering.RELAXED](1)
        except:
            # A running worker will take the job; with none, it would never run.
            if core[].words().live.load[ordering=Ordering.RELAXED]() == 0:
                abort("fp.effects: the blocking pool could not start a worker thread")
    _ = guard^
    # Joining exited workers outside the lock: they no longer need it.
    _ = joined^



def _worker_main(state: Pointer[_WorkerState, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    var owner = state[].core.take()
    var id = state[].id
    ref core = owner[]
    var random = _Random(_seed() ^ UInt64(id + 1))
    var poller: _Poller
    try:
        poller = _Poller()
    except:
        abort("fp.effects: a blocking worker could not create its poller")
    var worker = _WorkerContext(Pointer(to=poller).unsafe_origin_cast[MutUntrackedOrigin](), poller.interrupter())
    var deadline = Int(monotonic()) + core.idle_nanoseconds
    while True:
        var job = core.queue.pop(random)
        if job:
            job.take().execute(worker)
            deadline = Int(monotonic()) + core.idle_nanoseconds
            continue
        if core.closed() or Int(monotonic()) >= deadline:
            var decision = core._try_retire(id, random)
            if decision.retired:
                break
            decision.job.take().execute(worker)
            deadline = Int(monotonic()) + core.idle_nanoseconds
            continue
        # Publish, then re-read the queue (see the module's parking notes).
        core._park(id, worker.interrupter)
        var found = core.queue.pop(random)
        if found:
            _ = core._unpark(id)
            found.take().execute(worker)
            deadline = Int(monotonic()) + core.idle_nanoseconds
            continue
        if not core.closed():
            var remaining = max(deadline - Int(monotonic()), 0)
            try:
                _ = poller.poll(Optional(Duration.nanoseconds(remaining)))
            except:
                abort("fp.effects: a blocking worker's poll failed")
        _ = core._unpark(id)
    # Keep the poller, which calls borrowed through `worker`, alive until here.
    _ = worker^
    _ = poller^
    return None


struct _PoolOwner(Movable):
    """What every copy of a BlockingPool shares: closing the pool when the last is dropped."""
    var core: ArcPointer[_PoolCore]

    def __init__(out self, max_workers: Int, idle_nanoseconds: Int):
        self.core = ArcPointer(_PoolCore(max_workers, idle_nanoseconds))

    def __deinit__(deinit self):
        self.core[].close()


struct BlockingPool(Copyable):
    """Worker threads that run blocking calls, shared by the roots that hold it.

    `IO.blocking` and `IO.interruptible` run their functions here. A root
    uses the pool given in `IORuntimeConfig.blocking_pool`, or else a private
    pool with the defaults. Copies share one pool, which lives as long as its
    copies: when the last is dropped, it waits for the queued and running
    calls, then stops and joins its workers. A pool shared by several roots
    therefore outlives each root that finishes while another copy remains.

    Workers start on demand up to `max_workers`; an idle worker is reused for
    the next call and retires after `idle_timeout` without one. At the
    maximum, a call waits in a queue for the first free worker.

    If a call's function holds the last copy, the pool closes on that worker,
    which cannot join itself: it finishes its call and exits on its own.
    """
    var _owner: ArcPointer[_PoolOwner]

    def __init__(out self, max_workers: Int = _DEFAULT_MAX_WORKERS, idle_timeout: Duration = _default_idle()) raises:
        """Create a pool; no thread starts until the first call.

        Args:
            max_workers: The positive maximum number of worker threads; 64 by default.
            idle_timeout: How long a worker waits for a call before retiring;
                60 seconds by default.

        Raises:
            Error: `max_workers` is not positive.
        """
        comptime assert threads_supported, "the blocking pool is qualified only on 64-bit Linux"
        if max_workers <= 0:
            raise Error("BlockingPool max_workers must be positive")
        self._owner = ArcPointer(_PoolOwner(max_workers, idle_timeout.to_nanoseconds()))

    def _submit(self, var job: _Job):
        _submit(self._owner[].core, job^)

    def _live(self) -> Int:
        """Started workers that have not retired; a hint for tests."""
        return self._owner[].core[].live()

    def _started(self) -> Int:
        """Workers started since creation; a hint for tests."""
        return self._owner[].core[].started()

    def _parked(self) -> Int:
        """Workers on the idle list now; a hint for tests."""
        var guard = _lock_cell(self._owner[].core[].idle())
        var count = len(guard.value())
        _ = guard^
        return count


def _default_idle() -> Duration:
    var idle = Duration()
    idle._nanoseconds = _DEFAULT_IDLE_SECONDS * 1000000000
    return idle^


struct _RootBlocking(Copyable):
    """A root's pool and its calls in flight; every fiber of the root shares them.

    The root finishes by waiting for its calls, then dropping its copy of the
    pool, which closes the pool when no other copy remains.
    """
    var pool: BlockingPool
    var calls: _Calls

    def __init__(out self, var pool: BlockingPool):
        self.pool = pool^
        self.calls = _Calls()

    def submit(self, var body: _Erased, run: _RunJob):
        """Count the call for this root, then queue it."""
        self.calls.begin()
        self.pool._submit(_Job(body^, run, self.calls))

    def finish(deinit self):
        """Wait for this root's calls, then release its copy of the pool."""
        self.calls.wait()
        # Unused fields may be destroyed before a destructor's body: drop the
        # pool explicitly after the wait.
        _ = self.pool^


# ===------------------------------------------------------------------=== #
# The root's hook
# ===------------------------------------------------------------------=== #


# The root's slot is one word on `_Scheduler`: 0, or the address of a
# heap-allocated `_RootBlocking` that the slot owns. A root that never blocks
# leaves it 0, so creating and finishing it cost one load each.
#
# Orderings. An installer builds its candidate, then publishes it with a
# compare-exchange from 0 that is ACQUIRE_RELEASE on success: the release
# makes the candidate's construction visible to every thread that reads the
# address. A reader loads the word with ACQUIRE, and a losing installer's
# failed compare-exchange is ACQUIRE too, so either one sees the winner's
# fully built `_RootBlocking`; the loser drops its candidate, whose pool has
# started no thread. Exactly one compare-exchange from 0 succeeds, so the slot
# is installed once. The root's finish takes the address with an ACQUIRE
# compare-exchange to 0, after every blocking call of the root has completed, so no
# reader remains. Today only the polling thread installs; the
# compare-exchange keeps the install correct when 13c's workers race on it.


def _publish(word: Pointer[Atomic[Int], MutUntrackedOrigin], var root: _RootBlocking) -> Int:
    """Install `root` unless another installer won; returns the installed address."""
    var candidate = unsafe_alloc[_RootBlocking](1)
    candidate.unsafe_write(root^)
    var expected = 0
    if word[].compare_exchange[success_ordering=Ordering.ACQUIRE_RELEASE, failure_ordering=Ordering.ACQUIRE](expected, Int(candidate)):
        return Int(candidate)
    candidate.unsafe_deinit_pointee()
    candidate.unsafe_free()
    return expected


def _slot(scheduler: ArcPointer[_Scheduler]) -> Pointer[Atomic[Int], MutUntrackedOrigin]:
    return Pointer(to=scheduler[].blocking[]).unsafe_origin_cast[MutUntrackedOrigin]()


def _install_blocking(scheduler: ArcPointer[_Scheduler], pool: Optional[BlockingPool]):
    """Install a configured pool when the root is created; otherwise leave the slot empty."""
    if pool:
        _ = _publish(_slot(scheduler), _RootBlocking(pool.value().copy()))


def _root_blocking(scheduler: ArcPointer[_Scheduler]) -> _RootBlocking:
    """The running root's pool and call count, creating a private pool on first use."""
    var word = _slot(scheduler)
    var address = word[].load[ordering=Ordering.ACQUIRE]()
    if address == 0:
        var private: BlockingPool
        try:
            private = BlockingPool()
        except:
            abort("fp.effects: the default blocking pool configuration is invalid")
        address = _publish(word, _RootBlocking(private^))
    return Pointer[_RootBlocking, MutUntrackedOrigin](unsafe_from_address=address)[].copy()


def _finish_blocking(scheduler: ArcPointer[_Scheduler]):
    """Wait for the root's calls, then drop its copy of the pool; one load for a root that never blocked."""
    var word = _slot(scheduler)
    if word[].load[ordering=Ordering.ACQUIRE]() == 0:
        return
    # Atomic has no exchange: take the address with a compare-exchange to 0.
    var address = word[].load[ordering=Ordering.ACQUIRE]()
    while address != 0:
        if word[].compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.ACQUIRE](address, 0):
            break
    if address == 0:
        return
    var owned = Pointer[_RootBlocking, MutUntrackedOrigin](unsafe_from_address=address)
    var root = owned.unsafe_take_pointee()
    owned.unsafe_free()
    root^.finish()
