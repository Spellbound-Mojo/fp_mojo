"""The blocking pool: worker threads that run blocking functions for IO.blocking and IO.interruptible.

After Cats Effect's blocking execution context and Erlang's dirty I/O
schedulers. A pool owns a queue of jobs and up to `max_workers` OS threads.
Workers start on demand, take jobs in queue order, are reused while jobs keep
arriving, and retire after `idle_timeout` without work. A job runs one owned
function and completes the submitting fiber's `Completion` with its outcome;
the run loop never runs on a worker.

Ownership. A root owns a pool started on first use, or borrows a `BlockingPool`
shared by several roots. Finishing a root waits for its in-flight calls (their
callers wait for them anyway, so only the worker's last steps remain), closes a
pool it owns, and never stops a borrowed one. Closing a pool runs every queued
job, then stops and joins its workers. The pool is destroyed with its last
handle, which closes it.

Cross-thread rules. The pool is reached from the submitting threads and from
every worker, so every method takes immutable `self`, and its atomics live in
their own allocation behind a pointer (see the development guide's "Never
borrow a shared object mutably from two threads"). The job queue is S4's
`_ExternalQueue`; the worker list is a `_Cell` locked with the shared
`_lock_cell`.

Memory ordering of each atomic operation:

- `idle` counts workers waiting for a job, less the claims submitters made on
  them. A submitter pushes its job (under a stripe lock), executes
  `fence[SEQUENTIAL]`, then claims with a SEQUENTIAL compare-exchange. A worker
  that goes idle increments it with a SEQUENTIAL `fetch_add` before re-reading
  the queue. Every queue push and pop also passes through the stripe lock, so
  either the submitter sees the idle worker and claims it, or the worker's
  queue read sees the job; neither loses it. A worker leaving idle with a job
  decrements it only when positive (SEQUENTIAL compare-exchange); a claim has
  otherwise consumed its entry.
- `live` (started, not retired workers) and the worker list change only under
  the worker-list lock, which orders spawning against retiring: a retiring
  worker re-reads the queue under the lock after leaving idle, and a submitter
  that found no idle worker decides whether to spawn under the same lock.
  Loads outside the lock are RELAXED hints for tests.
- `started` counts every worker ever started; RELAXED, a test hint.
- `closed` is stored SEQUENTIAL by `close` and loaded ACQUIRE by workers and
  submitters; a worker that sees it with an empty queue exits.
- A root's in-flight count (`_Calls`) is incremented RELAXED before the job is
  published (the queue lock orders it), and decremented RELEASE by the worker
  after its last use of the job; the root's finish loads it ACQUIRE, so
  everything the worker did happens before the root returns.

Idle workers wait in `_idle_wait`. Until the S2 poller is on `nightly`, that is
a short sleep, so an idle pool wakes about a thousand times a second until
its workers retire; the poller replaces it, with submitters interrupting the
claimed worker.
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


comptime _RunJob = def(var _Erased) thin
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

    def execute(deinit self):
        """Run the call; the root's count drops after the worker's last use of it."""
        self.run(self.body^)
        self.calls.end()


# ===------------------------------------------------------------------=== #
# The pool
# ===------------------------------------------------------------------=== #


struct _Words(Movable):
    """The pool's atomics, each on its own cache line."""
    var idle: Atomic[Int]
    var _pad0: Array[Int, 7]
    var live: Atomic[Int]
    var _pad1: Array[Int, 7]
    var started: Atomic[Int]
    var _pad2: Array[Int, 7]
    var closed: Atomic[UInt8]
    var _pad3: Array[Int, 7]

    def __init__(out self):
        self.idle = Atomic(0)
        self._pad0 = Array[Int, 7](fill=0)
        self.live = Atomic(0)
        self._pad1 = Array[Int, 7](fill=0)
        self.started = Atomic(0)
        self._pad2 = Array[Int, 7](fill=0)
        self.closed = Atomic(UInt8(0))
        self._pad3 = Array[Int, 7](fill=0)


struct _WorkerState(Movable):
    """What a worker thread receives: its pool and its identity."""
    var core: Pointer[_PoolCore, MutUntrackedOrigin]
    var id: Int

    def __init__(out self, core: Pointer[_PoolCore, MutUntrackedOrigin], id: Int):
        self.core = core
        self.id = id


struct _Worker(Movable):
    var id: Int
    var thread: OSThread[_WorkerState]

    def __init__(out self, id: Int, var thread: OSThread[_WorkerState]):
        self.id = id
        self.thread = thread^


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


struct _PoolCore(Movable):
    """The shared state of one pool: reached from submitters and workers, always immutably."""
    var queue: _ExternalQueue[_Job]
    var _words: Pointer[_Words, MutUntrackedOrigin]
    var _workers: Pointer[_Cell[_Workers], MutUntrackedOrigin]
    var max_workers: Int
    var idle_nanoseconds: Int
    # This core's own address, which workers receive; set by its owner.
    var _self: Optional[Pointer[_PoolCore, MutUntrackedOrigin]]

    def __init__(out self, max_workers: Int, idle_nanoseconds: Int):
        self._self = None
        self.queue = _ExternalQueue[_Job](4)
        self._words = unsafe_alloc[_Words](1, alignment=64)
        self._words.unsafe_write(_Words())
        self._workers = unsafe_alloc[_Cell[_Workers]](1, alignment=64)
        self._workers.unsafe_write(_Cell(Atomic(UInt8(0)), Optional(_Workers())))
        self.max_workers = max_workers
        self.idle_nanoseconds = idle_nanoseconds

    def __deinit__(deinit self):
        # The owner closed the pool first: no worker or submitter remains.
        self._words.unsafe_deinit_pointee()
        self._words.unsafe_free()
        self._workers.unsafe_deinit_pointee()
        self._workers.unsafe_free()

    @always_inline
    def words(self) -> ref[MutUntrackedOrigin] _Words:
        return self._words[]

    @always_inline
    def workers(self) -> ref[MutUntrackedOrigin] _Cell[_Workers]:
        return self._workers[]

    def closed(self) -> Bool:
        return self.words().closed.load[ordering=Ordering.ACQUIRE]() != 0

    # Submission.

    def submit(self, var job: _Job):
        """Queue a job and make sure a worker will take it.

        Claims an idle worker, else starts one when fewer than the maximum run;
        at the maximum, the job waits for the first worker to finish its call.
        """
        if self.closed():
            abort("fp.effects: blocking call submitted to a closed BlockingPool")
        var random = _Random(_seed())
        self.queue.push(job^, random)
        fence[Ordering.SEQUENTIAL]()
        var idle = self.words().idle.load[ordering=Ordering.RELAXED]()
        while idle > 0:
            if self.words().idle.compare_exchange[success_ordering=Ordering.SEQUENTIAL, failure_ordering=Ordering.RELAXED](idle, idle - 1):
                # The claimed worker finds the job on its next queue read.
                return
        var joined: List[_Worker]
        var guard = _lock_cell(self.workers())
        ref workers = guard.cell[].slot.value()
        joined = workers.take_exited()
        if self.words().live.load[ordering=Ordering.RELAXED]() < self.max_workers:
            var id = workers.next_id
            workers.next_id += 1
            try:
                var thread = OSThread(ArcPointer(_WorkerState(self._self.value(), id)), _worker_main)
                workers.running.append(_Worker(id, thread^))
                _ = self.words().live.fetch_add[ordering=Ordering.RELAXED](1)
                _ = self.words().started.fetch_add[ordering=Ordering.RELAXED](1)
            except:
                # A running worker will take the job; with none, it would never run.
                if self.words().live.load[ordering=Ordering.RELAXED]() == 0:
                    abort("fp.effects: the blocking pool could not start a worker thread")
        _ = guard^
        # Joining exited workers outside the lock: they no longer need it.
        _ = joined^

    # Workers.

    def _leave_idle(self):
        """A worker with a job stops counting as idle, unless a claim already did that."""
        var idle = self.words().idle.load[ordering=Ordering.RELAXED]()
        while idle > 0:
            if self.words().idle.compare_exchange[success_ordering=Ordering.SEQUENTIAL, failure_ordering=Ordering.RELAXED](idle, idle - 1):
                return

    def _try_retire(self, id: Int, mut random: _Random) -> _Retirement:
        """Leave the pool unless a job arrived or a submitter claimed this worker.

        Decided under the worker-list lock, which submitters take to decide
        whether to start a worker, so a job is never left with no worker to run
        it. A claimed worker goes back to its loop: the claim consumed its idle
        entry, and it counts itself again if it finds nothing.
        """
        var guard = _lock_cell(self.workers())
        var idle = self.words().idle.load[ordering=Ordering.RELAXED]()
        var left = False
        while idle > 0:
            if self.words().idle.compare_exchange[success_ordering=Ordering.SEQUENTIAL, failure_ordering=Ordering.RELAXED](idle, idle - 1):
                left = True
                break
        if not left and not self.closed():
            # Mojo destroys a value after its last use: keep the lock held to here.
            _ = guard^
            return _Retirement(None, False)
        var job = self.queue.pop(random)
        if job:
            _ = guard^
            return _Retirement(job^, False)
        _ = self.words().live.fetch_sub[ordering=Ordering.RELAXED](1)
        guard.cell[].slot.value().exited.append(id)
        _ = guard^
        return _Retirement(None, True)

    def live(self) -> Int:
        return self.words().live.load[ordering=Ordering.RELAXED]()

    def started(self) -> Int:
        return self.words().started.load[ordering=Ordering.RELAXED]()

    def close(self):
        """Run every queued job, then stop and join every worker. Idempotent."""
        self.words().closed.store[ordering=Ordering.SEQUENTIAL](UInt8(1))
        var all: List[_Worker]
        var guard = _lock_cell(self.workers())
        all = guard.cell[].slot.value().take_all()
        _ = guard^
        # Each worker drains the queue, sees the flag and exits; dropping joins it.
        _ = all^
        # A job left by a submitter that raced the close would never run.
        var random = _Random(_seed())
        var left = self.queue.pop(random)
        if left:
            abort("fp.effects: blocking call submitted while its BlockingPool closed")


def _idle_wait():
    # Until S2's poller merges: a short sleep. The poller replaces this with a
    # park that submitters interrupt.
    sleep(0.0005)


def _worker_main(state: Pointer[_WorkerState, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    ref core = state[].core[]
    var id = state[].id
    var random = _Random(_seed() ^ UInt64(id + 1))
    while True:
        var job = core.queue.pop(random)
        if job:
            job.take().execute()
            continue
        # Idle: count it, then re-read the queue (see the module's ordering notes).
        _ = core.words().idle.fetch_add[ordering=Ordering.SEQUENTIAL](1)
        var deadline = monotonic() + core.idle_nanoseconds
        while True:
            var found = core.queue.pop(random)
            if found:
                core._leave_idle()
                found.take().execute()
                break
            if core.closed() or monotonic() >= deadline:
                var decision = core._try_retire(id, random)
                if decision.retired:
                    return None
                if decision.job:
                    decision.job.take().execute()
                # Claimed, or ran the last job: back to the main loop.
                break
            _idle_wait()


struct _PoolOwner(Movable):
    """The one owner of a pool's core; closing and freeing it on destruction."""
    var _core: Pointer[_PoolCore, MutUntrackedOrigin]

    def __init__(out self, max_workers: Int, idle_nanoseconds: Int):
        self._core = unsafe_alloc[_PoolCore](1, alignment=64)
        self._core.unsafe_write(_PoolCore(max_workers, idle_nanoseconds))
        self._core[]._self = Optional(self._core)

    def __deinit__(deinit self):
        self._core[].close()
        self._core.unsafe_deinit_pointee()
        self._core.unsafe_free()

    @always_inline
    def core(self) -> ref[MutUntrackedOrigin] _PoolCore:
        return self._core[]


struct BlockingPool(Copyable):
    """Worker threads that run blocking calls, shared by the roots that borrow it.

    `IO.blocking` and `IO.interruptible` run their functions here. Each root
    owns a pool started on first use, configured by `IORuntimeConfig`; a
    `BlockingPool` given to `IORuntimeConfig.blocking` is borrowed instead, and
    can serve several roots at once. Finishing a root waits for its calls but
    never stops a borrowed pool. Copies share one pool, which closes when the
    last copy is dropped or `close` is called.

    Workers start on demand up to `max_workers`; an idle worker is reused for
    the next call and retires after `idle_timeout` without one. At the
    maximum, a call waits in a queue for the first free worker.
    """
    var _owner: ArcPointer[_PoolOwner]

    def __init__(out self, max_workers: Int = _DEFAULT_MAX_WORKERS) raises:
        """Create a pool with the default 60-second idle timeout.

        Args:
            max_workers: The positive maximum number of worker threads.

        Raises:
            Error: `max_workers` is not positive.
        """
        self = Self(max_workers, Duration.seconds(_DEFAULT_IDLE_SECONDS))

    def __init__(out self, max_workers: Int, idle_timeout: Duration) raises:
        """Create a pool; no thread starts until the first call.

        Args:
            max_workers: The positive maximum number of worker threads.
            idle_timeout: How long a worker waits for a call before retiring.

        Raises:
            Error: `max_workers` is not positive.
        """
        comptime assert threads_supported, "the blocking pool is qualified only on 64-bit Linux"
        if max_workers <= 0:
            raise Error("BlockingPool max_workers must be positive")
        self._owner = ArcPointer(_PoolOwner(max_workers, idle_timeout.to_nanoseconds()))

    def close(self):
        """Run every queued call, then stop and join the workers.

        Call it only when no root using the pool can submit another call;
        a call submitted after `close` aborts. Closing again does nothing.
        """
        self._owner[].core().close()

    def _submit(self, var job: _Job):
        self._owner[].core().submit(job^)

    def _live(self) -> Int:
        """Started workers that have not retired; a hint for tests."""
        return self._owner[].core().live()

    def _started(self) -> Int:
        """Workers started since creation; a hint for tests."""
        return self._owner[].core().started()


struct _RootBlocking(Copyable):
    """A root's access to its blocking pool; every context under the root shares it.

    The root's own pool is created on the first call. A borrowed pool is
    shared from the start. `finish` waits for the root's calls, then closes
    an owned pool.
    """
    var _pool: ArcPointer[_Cell[Optional[BlockingPool]]]
    var _calls: _Calls
    var _owned: Bool
    var _max_workers: Int
    var _idle_nanoseconds: Int

    def __init__(out self, borrowed: Optional[BlockingPool], max_workers: Int, idle_nanoseconds: Int):
        self._owned = not borrowed
        self._pool = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(borrowed.copy())))
        self._calls = _Calls()
        self._max_workers = max_workers
        self._idle_nanoseconds = idle_nanoseconds

    def pool(self) -> BlockingPool:
        var guard = _lock_cell(self._pool[])
        ref slot = guard.cell[].slot.value()
        if not slot:
            try:
                slot = Optional(BlockingPool(self._max_workers, Duration.nanoseconds(self._idle_nanoseconds)))
            except:
                abort("fp.effects: invalid blocking pool configuration")
        var pool = slot.value().copy()
        _ = guard^
        return pool^

    def submit(self, var body: _Erased, run: _RunJob):
        """Count the call for this root, then queue it."""
        self._calls.begin()
        self.pool()._submit(_Job(body^, run, self._calls))

    def finish(self):
        """Wait for this root's calls; close the pool if the root owns it."""
        self._calls.wait()
        if not self._owned:
            return
        var guard = _lock_cell(self._pool[])
        var pool = guard.cell[].slot.value().take() if guard.cell[].slot.value() else Optional[BlockingPool]()
        _ = guard^
        if pool:
            pool.value().close()
