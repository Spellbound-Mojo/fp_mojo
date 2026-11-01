"""The work-stealing pool: workers on OS threads, stealing, parking in pollers.

After Cats Effect's `WorkStealingThreadPool` and `WorkerThread`, on the
concurrent structures in `scheduling/` and the poller (`polling.mojo`). This is
the work-stealing profile's private core. The current-thread profile
is the executor in `executor.mojo`. Both run the same tasks
(`_TaskHeader`), wake registries, fibers, ownership and run path
(`_Executor.run_body` and `settle`); only where a woken task is queued and who
runs it differ.

Shape:

- A pool has `workers` workers, by default one per logical processor. Each
  has a fixed-capacity local ring (`_LocalQueue`) with one producer, its
  owner, and many stealers, and its own poller, in which it parks. The pool
  also has one striped external queue (`_ExternalQueue`) for work submitted
  from outside and for rings that overflow, and the parking state machine
  (`_Parking`).
- Worker 0 may be the calling thread: a per-call `run` runs the root there
  and starts the other workers only when there is work to steal (the Runtime
  API's item 6). Workers not yet started count as parked, and the notifier
  that claims one starts its thread instead of unparking it. A pool may also
  start every worker at once (`start_all`), for a long-lived runtime whose
  caller only waits (`_RootHandle.wait`).
- The pool names the worker on the current thread with a pthread key
  (`ThreadKey`), as Cats Effect asks whether `Thread.currentThread()` is one
  of its pool's `WorkerThread`s.

Wakes. A root's scheduler reaches the pool through
`_Dispatch` (`waking.mojo`). A task made scheduled on one of this pool's
workers by the task that worker is running goes into its LIFO slot; on one
of its workers otherwise, onto that worker's ring; from any other thread,
onto the external queue. After the registry lock is released, `notify` wakes
a parked worker when no worker is searching and not all are active. Filling
an empty LIFO slot never notifies, and a push onto the worker's own ring
(including a slot occupant it displaces) notifies only when the ring then
holds more than one entry; otherwise the worker is about to run the entry
itself, which is what keeps a `run` that never starts a fiber on one thread.
A wake while the task runs marks it notified, and the run's end requeues it
(`_Runtime.park`) onto the ring.

The LIFO slot (after Tokio's `lifo_slot`): one
owner-only entry per worker, in `_WorkerSlot`'s owner line, which stealers
never see. A task woken by the running task runs next on the same worker,
instead of going through the ring to another worker at the poller's wake
latency; the slot's previous occupant moves to the back of the ring. The
worker takes from the slot before `_find`, at most `_MAX_LIFO_RUNS` (Tokio's
`MAX_LIFO_POLLS_PER_TICK`) times in a row, and then sends the occupant to the
back of the ring; any trip through `_find` resets the count, so two tasks
waking each other cannot starve the ring. The worker flushes the slot to the
ring (`_flush_lifo`) before it parks and when it leaves its loop, unless it
retired, when the slot belongs to its replacement with the ring. A task in a
busy worker's slot is invisible to idle workers only until the current run
ends, which its transition slice bounds. The same slice bounds how long a
displaced task waits un-notified on a busy worker's ring: workers already
active or searching can steal it at once, and the end of the run either
takes it or requeues the running task beside it, which notifies.

The worker loop (`run_worker`), after `WorkerThread.run`:

0. The LIFO slot's task, within its bound (above).
1. Every 61st iteration, take a batch from the external queue first, so
   outside submissions are not starved, and fire due timers.
2. Its own ring.
3. A batch from the external queue.
4. With permission to search (at most half the workers search at once), other
   workers' expired timers, then half of a victim's ring, each scanning from a
   random worker.
5. Otherwise fire due timers, and if none fired, park in its own poller until
   its own next deadline or a notifier's interrupt.

A task run gets its own full transition slice (`_TaskRun`'s flag), Cats
Effect's per-fiber auto-yield, and an exhausted run goes to the back of its
worker's ring.

Hooks. Named methods that extend the loop without editing it:

- (a) timers: each worker owns one
  `_TimerHeap` of `_Waker`s, which only it inserts into, fires from and
  restructures. A deadline armed during a task run goes into the running
  worker's heap (`_pool_timer`, reached through `_Scheduler.start_timer` under
  the registry's lock, where its handle is stored). Clearing it cancels it
  there: at once on the owner (`cancel_owned`); from any other thread by
  marking and counting the node (`cancel`), which the owner removes once
  counted cancellations reach half its heap (`pack_if_needed`, run whenever it
  fires timers). `fire_timers` fires the owner's due timers onto its own ring,
  `next_deadline` is its park timeout, and a searching worker takes other
  workers' expired timers (`steal_timers`) and fires them on its own thread.
  The wake registry's epoch and generation checks decide whether a fired or
  stolen timer is still live, under the registry's lock.
- (b) the blocking hand-off: `_current_worker`/`_worker_on`,
  `hand_off_for_blocking`, and `retired`, checked after every task run. A
  call registered during a run is stashed in the slot; when the run ends the
  worker hands its slot to a replacement thread from the pool's thread cache
  (`blockers`, a blocking-pool core) and runs the call on this thread
  (`_hand_off`). At most `max_blocked` calls hand off at once; the rest queue
  on the root's `BlockingPool`. `close_blocking` stops the cache at shutdown.
  A thread inside a handed-off call is not a worker: it may call
  `Runtime.run`, and it touches no pool memory after its call. The
  scheduler page's "Blocking hand-off" gives the protocol and its orderings.
- (c) shutdown: `shutdown`, or `shutdown_on_worker` when a `Runtime`'s last
  copy is dropped on one of its own workers; `closing`, checked at the top of
  every iteration and before parking; and `drain_on_shutdown`, which drops
  the entries left on a leaving worker's ring on its own thread. The owner
  shuts down only after every root it ran completed, so such entries are
  stale wakes of finished tasks.

Ownership and lifetime. The pool is held by `ArcPointer` and used only
through immutable `self`; per-worker state lives in one allocation of padded
slots reached through untracked pointers, so no thread ever borrows another's
state, or its own, as `mut` across a task run that may push onto it. A pool
outlives every root it runs, and its owner calls `shutdown`, which joins every
started thread, before dropping it. Each worker's poller lives in its slot
until the pool is destroyed, so an interrupt never reaches a destroyed poller.

Memory ordering of each atomic operation the pool adds (the structures it uses
document their own):

- A slot's `poller` word: stored SEQUENTIAL by its worker, once, before the
  worker first publishes PARKED (`prepare_to_park`, a RELEASE store). A
  notifier loads it ACQUIRE after its ACQUIRE claim of that flag, so the
  claimed worker's poller is visible. Shutdown stores `closing` and then
  loads the word, both SEQUENTIAL, and the worker stores the word and later
  loads `closing`, both SEQUENTIAL: either shutdown sees the poller and
  interrupts it, or the worker sees `closing` and does not wait.
- A slot's `thread` field: written by the starter between its claim and
  `finish_unpark` (RELEASE); shutdown reads it after waiting, with ACQUIRE
  loads, for the flag to leave INTERRUPTING.
- `closing`: SEQUENTIAL store and loads (above).
- Foreign wakes use the root scheduler's `in_flight` and `closed` words
  (`_Dispatch` in `waking.mojo`).
- The timer heaps: `scheduling/timer_heap.mojo` documents each atomic. A
  heap ticket reaches a canceling thread only through the registry node,
  under the registry's lock, which orders it after the insert.
- `stolen_timers`, `failed_starts`, `reclaimed`, `delivered_wakes`: RELAXED;
  diagnostic counts, read only by tests and probes, which order nothing by them.
- `parked_waits`: RELAXED; a heuristic count of `Runtime.run` waits that
  parked in a row (`_spin_for_done`), which orders no data.
- A handed-off slot's claim (`_SlotClaim`): one ACQUIRE_RELEASE compare-exchange
  between the cache thread that pops its job and the caller as worker 0
  taking it back; see `_SlotClaim`.
- A worker's heap's `opened` word (`_WorkerTimers`): the owner writes the
  heap, then stores 1 RELEASE; other threads load it ACQUIRE before they
  cancel into or steal from the heap. The owner's own check is RELAXED.
- `blockers`, the thread cache's address (hook b): installed once by a
  compare-exchange from 0, ACQUIRE_RELEASE on success and ACQUIRE on failure,
  and loaded ACQUIRE (`blockers()`); freed with the pool.
- The cap of handed-off calls (`_Calls.begin_below`): RELAXED; it bounds
  threads and orders no data (`blocking_pool.mojo`).
- Owner-only fields of `_WorkerSlot` (`random`, `tick`, `running`,
  `retired`, `lifo`, `lifo_runs`, `blocked`, `keep`) are plain: only the
  thread running the worker touches them, and `index` never changes. They change hands with the slot on
  a blocking hand-off, ordered by `pthread_create` or the thread cache's
  stripe lock (`_hand_off`).
- `_RootDone`: see `_RootResult.complete`.
"""
from std.atomic import Atomic, Ordering
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import monotonic, sleep
from fp._internal.cells import _Cell
from fp._internal.erased import _Erased
from fp._internal.oneshot import _OneShot
from fp._internal.os import OSError, OSThread, ThreadKey
from fp._internal.time import Duration, Instant
from fp._internal.waking import Signal, _Clock, _PaddedCount, _Dispatch, _Registrations, _Runtime, _Scheduler, _TaskHeader, _TimerHandle, _TimerState, _Waker, _deadline_ticks
from fp.effects import CancellationToken, IOContext, Outcome
from fp.effects._io_core import _Budget
from .executor import _Executor
from .kernel import IORuntimeConfig, Machine, _Slot, _tick
from .polling import _Poller, _interrupt_at, _finish_root_poller
from .scheduling.blocking_pool import _Calls, _DEFAULT_MAX_WORKERS, _Job, _PoolOwner, _WorkerContext, _default_idle, _finish_blocking, _install_blocking, _open_poller, _serve_adopted, _submit
from .scheduling.external_queue import _ExternalQueue
from .scheduling.local_queue import _LocalQueue
from .scheduling.parking import _Parking, _UNPARK_SPINS
from .scheduling.timer_heap import _TimerHeap
from .scheduling.random import _Random

comptime _Entry = ArcPointer[_TaskHeader]
"""A queue entry: the right to run a scheduled task."""

comptime _EXTERNAL_CHECK = 61
"""Iterations between a worker's checks of the external queue and the timers, as in Cats Effect."""

comptime _MAX_LIFO_RUNS = 3
"""Consecutive runs from a worker's LIFO slot before its ring runs, Tokio's `MAX_LIFO_POLLS_PER_TICK`."""


comptime _TimerHeapOf = _TimerHeap[_Waker]
"""A worker's timer heap: the deadlines armed on it, each waking one registration."""

comptime _STEAL_TIMERS = 32
"""The most expired timers a searching worker takes in one scan."""


struct _WorkerTimers(Movable):
    """A worker's timer heap, opened on its first deadline, so a pool that never sleeps allocates none.

    The owner writes `heap` once, then stores `opened` RELEASE; other
    threads load it ACQUIRE before touching the heap. A canceler holds a
    ticket from an insert, so the heap it names is open.
    """
    var opened: Atomic[Int]
    var heap: Optional[_TimerHeapOf]

    def __init__(out self):
        self.opened = Atomic(0)
        self.heap = None


struct _WorkerSlot(Movable):
    """One worker's state: the parts other threads read, then the owner's own line."""
    # Shared with stealers and pushers; the ring holds only pointers to its
    # own allocations, so borrowing this field never covers the entries.
    var queue: _LocalQueue[_Entry]
    # The worker's poller's address, 0 until it first parks (see the module docstring).
    var poller: Atomic[Int]
    var _padding_shared: Array[Int, 5]
    # Owner-only: written only on the worker's own thread.
    var random: _Random
    var tick: Int
    var index: Int
    var running: Bool
    # Hook (b): set with `blocked` by a call handed off during the current
    # run; the loop then leaves and the thread runs the call (`run_worker`).
    var retired: Bool
    # The LIFO slot (see the module docstring): the task woken last by the
    # running task, which thieves never see, and the consecutive runs from it.
    var lifo: Optional[_Entry]
    var lifo_runs: Int
    var _padding_owner: Array[Int, 1]
    # Owner-only: the call handed off during the current run (hook b).
    var blocked: Optional[_Job]
    # Written by the thread's starter, taken by shutdown (see the module docstring).
    var thread: Optional[OSThread[_Boot]]
    # Owner-only: the pool's last reference, when its owner was dropped on this
    # worker (`shutdown_on_worker`); the thread drops it after its loop.
    var keep: Optional[ArcPointer[_Pool]]

    def __init__(out self, index: Int, seed: UInt64):
        self.queue = _LocalQueue[_Entry]()
        self.poller = Atomic(0)
        self._padding_shared = Array[Int, 5](fill=0)
        self.random = _Random(seed)
        self.tick = 0
        self.index = index
        self.running = False
        self.retired = False
        self.lifo = None
        self.lifo_runs = 0
        self._padding_owner = Array[Int, 1](fill=0)
        self.blocked = None
        self.thread = None
        self.keep = None


struct _Boot(Movable):
    """What a started worker thread receives: its pool's address and its index."""
    var pool: Int
    var index: Int

    def __init__(out self, pool: Int, index: Int):
        self.pool = pool
        self.index = index


struct _PoolWords(Movable):
    """The pool's own cross-thread words, each on its own line."""
    var closing: Atomic[Int]
    var _padding_closing: Array[Int, 7]
    # Diagnostic: timers fired by a worker other than their heap's owner (RELAXED).
    var stolen_timers: Atomic[Int]
    var _padding_stolen: Array[Int, 7]
    # Diagnostic: lazy starts whose thread could not be created (RELAXED).
    var failed_starts: Atomic[Int]
    var _padding_failed: Array[Int, 7]
    # Hook (b): the address of the pool's `_Blockers`, 0 until the first hand-off.
    var blockers: Atomic[Int]
    var _padding_blockers: Array[Int, 7]
    # Diagnostic: slots the caller as worker 0 took back after a call (RELAXED).
    var reclaimed: Atomic[Int]
    var _padding_reclaimed: Array[Int, 7]
    # `Runtime.run`'s waits that ended parked, in a row (RELAXED; a heuristic, `_spin_for_done`).
    var parked_waits: Atomic[Int]
    var _padding_parked: Array[Int, 7]
    # Diagnostic: claims in `notify` that interrupted a parked worker or started one (RELAXED).
    var delivered_wakes: Atomic[Int]
    var _padding_delivered: Array[Int, 7]

    def __init__(out self):
        self.closing = Atomic(0)
        self._padding_closing = Array[Int, 7](fill=0)
        self.stolen_timers = Atomic(0)
        self._padding_stolen = Array[Int, 7](fill=0)
        self.failed_starts = Atomic(0)
        self._padding_failed = Array[Int, 7](fill=0)
        self.blockers = Atomic(0)
        self._padding_blockers = Array[Int, 7](fill=0)
        self.reclaimed = Atomic(0)
        self._padding_reclaimed = Array[Int, 7](fill=0)
        self.parked_waits = Atomic(0)
        self._padding_parked = Array[Int, 7](fill=0)
        self.delivered_wakes = Atomic(0)
        self._padding_delivered = Array[Int, 7](fill=0)


@always_inline
def _pool_at(target: Int) -> Pointer[_Pool, MutUntrackedOrigin]:
    return Pointer[_Pool, MutUntrackedOrigin](unsafe_from_address=target)


def _pool_push(target: Int, var task: _Entry) -> Bool:
    """`_Dispatch.push`: onto the running worker's ring, else the external queue; true to notify."""
    var pool = _pool_at(target)
    var current = pool[].key.get()
    if current:
        var slot = Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)
        var queue = Pointer(to=slot[].queue).unsafe_origin_cast[MutUntrackedOrigin]()
        var random = Pointer(to=slot[].random).unsafe_origin_cast[MutUntrackedOrigin]()
        if slot[].running:
            # Woken by the running task: into the LIFO slot, which needs no
            # notify. A displaced occupant goes to the back of the ring, which
            # notifies only when it then holds more than one entry (the
            # own-ring rule; Tokio always notifies here, which kept a fiber
            # pair at about 23 µs).
            var lifo = Pointer(to=slot[].lifo).unsafe_origin_cast[MutUntrackedOrigin]()
            var previous = lifo[].take() if lifo[] else Optional[_Entry](None)
            lifo[] = Optional(task^)
            if not previous:
                return False
            queue[].enqueue(previous.take(), pool[].external, random[])
            return queue[].len() > 1
        queue[].enqueue(task^, pool[].external, random[])
        # The worker runs its next entry itself unless it has more.
        return queue[].len() > 1
    # A foreign wake: the root's scheduler holds it in its notify-or-close
    # handshake until the notify that follows (`_Scheduler.push`).
    var random = _Random(UInt64(Int(_TaskHeader.state_of(task))) ^ UInt64(monotonic()))
    pool[].external.push(task^, random)
    return True


def _pool_notify(target: Int):
    """`_Dispatch.notify`: wake a parked worker, or start one, if work needs it."""
    var pool = _pool_at(target)
    var current = pool[].key.get()
    if current:
        var slot = Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)
        var random = Pointer(to=slot[].random).unsafe_origin_cast[MutUntrackedOrigin]()
        pool[].notify(target, random[])
    else:
        var random = _Random(UInt64(monotonic()))
        pool[].notify(target, random)


def _pool_foreign(target: Int) -> Bool:
    """`_Dispatch.foreign`: whether the calling thread is not one of the pool's workers."""
    return _pool_at(target)[].key.get() == 0


def _pool_shard(target: Int) -> Int:
    """`_Dispatch.shard`: the running worker's index, or 0 off the pool."""
    var current = _pool_at(target)[].key.get()
    if not current:
        return 0
    return Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)[].index


def _pool_timer(target: Int, deadline: UInt64, var waker: _Waker) -> _TimerHandle:
    """`_Dispatch.timer`: insert into the running worker's own heap; under the registry's lock.

    Only task runs arm deadlines, and tasks run only on workers.
    """
    var pool = _pool_at(target)
    var current = pool[].key.get()
    if not current:
        abort("fp.effects: a deadline was armed off its pool's workers")
    var index = Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)[].index
    var ticket = pool[]._own_heap(index)[].insert(deadline, waker^)
    return _TimerHandle(index, ticket^)


def _pool_cancel_timer(target: Int, handle: _TimerHandle):
    """`_Dispatch.cancel_timer`: remove at once on the owning worker, else mark and count; under the registry's lock.

    The waker taken out refers to the registry whose lock is held, so
    dropping it here never drops that registry.
    """
    if handle.worker < 0:
        return
    var pool = _pool_at(target)
    var heap = pool[]._heap(handle.worker)
    var current = pool[].key.get()
    if current and Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)[].index == handle.worker:
        _ = heap[].cancel_owned(handle.ticket)
    else:
        _ = heap[].cancel(handle.ticket)


def _on_own_thread(pool: _Pool) -> Int:
    """The one test of whether the calling thread belongs to `pool`: its worker's index, or -1.

    `Runtime` uses it to reject `run` on its own workers and to detach instead
    of joining when its last copy is dropped on one. A replacement thread
    running a slot after a blocking hand-off holds the worker key, so it
    counts. A thread inside a handed-off call does not: it is no longer a
    worker, so `Runtime.run` there blocks no worker the program needs, as
    Cats Effect allows `unsafeRunSync` inside `blocking`; and it never drops
    the runtime's last copy, since `run` borrows a copy until its root
    completes, which waits for the call (`_Calls`).
    """
    var current = pool.key.get()
    if not current:
        return -1
    return Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)[].index


def _release_kept(target: Int, index: Int):
    """Drop the pool's last reference if `shutdown_on_worker` handed it to worker `index`'s thread, the one leaving it now."""
    # A worker detached by `shutdown_on_worker` holds the pool's last
    # reference here; the pool is destroyed on this thread, after its loop.
    var slot = _pool_at(target)[]._slot(index)
    if slot[].keep:
        var keep = slot[].keep.take()
        _ = keep^


def _worker_entry(boot: Pointer[_Boot, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    """A started worker's thread: run the loop as a searcher, as a woken worker resumes.

    After a hand-off it runs the call, then offers itself for reuse in the
    pool's thread cache until it retires. Its starter joins it at shutdown
    (`slot.thread`), after `close_blocking`.
    """
    var target = boot[].pool
    var index = boot[].index
    var blocked = _pool_at(target)[].run_worker(target, index, True, 0)
    if blocked:
        # This thread left the worker: the slot, and its `keep`, are now its
        # replacement's (`_run_slot`).
        var owner = _pool_at(target)[].blockers()[].owner.core.copy()
        var poller = _open_poller()
        var context = _WorkerContext(Pointer(to=poller).unsafe_origin_cast[MutUntrackedOrigin]())
        # The call may outlive the pool's last use (its root completes once
        # the call's counts drop), so this thread touches only the cache.
        blocked.take().execute(context)
        _serve_adopted(owner, context.poller)
        _ = poller^
        return OptionalPointer[NoneType, MutUntrackedOrigin]()
    _release_kept(target, index)
    return OptionalPointer[NoneType, MutUntrackedOrigin]()


struct _SlotClaim(Copyable):
    """Who runs a handed-off slot: the cache thread that pops its job, or the caller as worker 0 taking it back; copies share it.

    One compare-exchange from 0 decides, ACQUIRE_RELEASE on success. Each
    party's view of the slot is already ordered (the cache queue's stripe
    lock, or `pthread_create`, for a cache thread; program order for the
    caller, which wrote the slot last), so the claim orders nothing more but
    is self-contained. The loser touches no pool memory: the claim lives in
    its own allocation, so a cache thread that pops the job after the pool was
    freed reads only the claim.
    """
    var _word: ArcPointer[_PaddedCount]

    def __init__(out self):
        self._word = ArcPointer(_PaddedCount())

    def take(self) -> Bool:
        """Claim the slot; true for exactly one caller."""
        var expected = 0
        return self._word[].value.compare_exchange[success_ordering=Ordering.ACQUIRE_RELEASE, failure_ordering=Ordering.RELAXED](expected, 1)


@fieldwise_init
struct _SlotJob(Movable):
    """A thread cache job: become worker `index` of the pool at `pool`, replacing a thread that handed it off, unless `claim` was taken."""
    var pool: Int
    var index: Int
    var claim: _SlotClaim


def _run_slot(var body: _Erased, thread: _WorkerContext):
    """Run a handed-off worker on a cache thread; after its own hand-off, run the call here and return to the cache.

    The replacement inherits the slot's parking state, active and not
    searching, then asks to search before it runs, as a worker that found
    nothing does. A non-searcher parks without re-checking the queues, which
    is safe only for a worker refused permission (a searcher re-checks after
    it): a replacement that kept the inherited state could park just as the
    call's completion, pushed from the thread that left, found every worker
    active and woke none (`wstp_blocking` hung 1 run in 100 that way).
    """
    var job = body^.take[_SlotJob]()
    if not job.claim.take():
        # The caller as worker 0 took its slot back after its call, and its
        # pool may be gone: touch nothing of it.
        return
    var searching = _pool_at(job.pool)[].parking.transition_to_searching()
    var blocked = _pool_at(job.pool)[].run_worker(job.pool, job.index, searching, 0)
    if blocked:
        # As in `_worker_entry`, nothing of the pool is touched after the call.
        blocked.take().execute(thread)
        return
    _release_kept(job.pool, job.index)


struct _WorkerRef(Copyable, TrivialRegisterPassable):
    """The worker running on the current thread; for the blocking hand-off (hook b)."""
    var pool: Int
    var slot: Int

    def __init__(out self, pool: Int, slot: Int):
        self.pool = pool
        self.slot = slot

    def hand_off_for_blocking(self, var job: _Job) -> Optional[_Job]:
        """Hook (b): take a blocking call to run on this thread once the current task run ends.

        Called by the call's registration, inside the task run. The worker
        stashes the job and marks itself `retired`; when the run ends, its
        loop hands the slot to a replacement thread and leaves, and this
        thread runs the call (`run_worker`). Returns the job, refused, when the
        worker is not inside a run, already holds a call, the pool is closing,
        or the cap of calls blocked at once is reached (read before written);
        the caller then queues it on the root's pool.
        """
        var pool = _pool_at(self.pool)
        var slot = Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=self.slot)
        if not slot[].running or slot[].retired or pool[].closing():
            return job^
        var blockers = pool[].blockers()
        if not blockers[].blocked.begin_below(pool[].max_blocked):
            return job^
        job.held = Optional(blockers[].blocked.copy())
        slot[].blocked = Optional(job^)
        slot[].retired = True
        return None


def _worker_on(target: Int) -> Optional[_WorkerRef]:
    """Hook (b): the worker of the pool at `target` running on this thread, if any."""
    var current = _pool_at(target)[].key.get()
    if not current:
        return None
    return Optional(_WorkerRef(target, current))


def _current_worker(scheduler: ArcPointer[_Scheduler]) -> Optional[_WorkerRef]:
    """Hook (b): the worker of `scheduler`'s pool running on this thread, if any."""
    if not scheduler[].pooled():
        return None
    return _worker_on(scheduler[].dispatch.target)


struct _Blockers(Movable):
    """Hook (b): the thread cache that replaces handed-off workers, and its counts; made on a pool's first hand-off.

    - `owner`: a private blocking-pool core whose jobs run worker slots.
    - `blocked`: calls handed off and not yet returned, bounded by the cap.
    - `slot_jobs`: the cache jobs' own count, which nothing waits for.
    """
    var owner: _PoolOwner
    var blocked: _Calls
    var slot_jobs: _Calls

    def __init__(out self, max_threads: Int, idle_nanoseconds: Int):
        self.owner = _PoolOwner(max_threads, idle_nanoseconds)
        self.blocked = _Calls()
        self.slot_jobs = _Calls()


def _worker_poller(scheduler: ArcPointer[_Scheduler], create: Bool) -> Int:
    """The running worker's own poller, for descriptor waits; 0 off the pool's workers.

    With `create`, it is opened on first use (`_Pool._ensure_poller`), on the
    worker's own thread before it next parks.
    """
    var target = scheduler[].dispatch.target
    var current = _pool_at(target)[].key.get()
    if not current:
        return 0
    var slot = Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)
    if not create:
        return slot[].poller.load[ordering=Ordering.RELAXED]()
    return Int(_pool_at(target)[]._ensure_poller(slot))


struct _Pool(Movable):
    """A work-stealing pool of workers; see the module docstring. Every method takes immutable `self`."""
    var _workers: Int
    var _slots: Pointer[_WorkerSlot, MutUntrackedOrigin]
    var external: _ExternalQueue[_Entry]
    var parking: _Parking
    var key: ThreadKey
    # One timer heap per worker (hook a), apart from the slots so that a task
    # destroyed with a ring can still cancel into any heap.
    var _heaps: Pointer[_WorkerTimers, MutUntrackedOrigin]
    # The empty root heap every root's scheduler holds and never uses (`_Scheduler`).
    var _root_timers: ArcPointer[_Cell[_TimerState]]
    var _words: Pointer[_PoolWords, MutUntrackedOrigin]
    # Hook (b): the cap of calls handed off at once and the thread cache's
    # idle timeout. The cache itself (`_Blockers`) is made on the first hand-off, so a per-call
    # `run` that never blocks pays nothing for it.
    var max_blocked: Int
    var _blocking_idle: Int
    # The native stack size of every worker thread the pool starts, 0 for the
    # system default (`OSThread`). Private: qualification's bounded-stack
    # client runs the pool with 1 MiB stacks. Threads of the
    # blocking hand-off's cache keep the default.
    var _stack_bytes: Int

    def __init__(out self, workers: Int, started: Int, *, max_blocking_threads: Int = _DEFAULT_MAX_WORKERS, blocking_idle_timeout: Duration = _default_idle(), stack_bytes: Int = 0) raises OSError:
        """A pool of `workers`, of which the first `started` run from the start (0 or 1).

        With `started` 1 the calling thread is worker 0 (`run_worker`); every
        other worker starts lazily, when a notifier claims it. At most
        `max_blocking_threads` calls are handed off at once; further calls
        queue on their root's `BlockingPool`. A thread that ran a handed-off
        call retires after `blocking_idle_timeout` without being reused.
        Started worker threads get `stack_bytes` of native stack, or the
        system default when it is 0 (`OSThread`); the caller as worker 0 keeps
        its own stack.

        Raises:
            OSError: No thread key was left.
        """
        if max_blocking_threads <= 0:
            abort("fp.effects: a work-stealing pool needs a positive cap of blocking threads")
        if workers < 1 or workers > 1 << 15:
            abort("fp.effects: a work-stealing pool needs 1 to 32768 workers")
        if started < 0 or started > 1:
            abort("fp.effects: a pool starts with no worker or with the caller as worker 0")
        self._workers = workers
        self.key = ThreadKey()
        self._slots = unsafe_alloc[_WorkerSlot](workers, alignment=64)
        var seed = UInt64(monotonic())
        for i in range(workers):
            self._slots.unsafe_offset(i).unsafe_write(_WorkerSlot(i, seed + UInt64(i) * 0x9E3779B97F4A7C15))
        self.external = _ExternalQueue[_Entry](workers)
        self.parking = _Parking(workers, started)
        self._heaps = unsafe_alloc[_WorkerTimers](workers, alignment=64)
        for i in range(workers):
            self._heaps.unsafe_offset(i).unsafe_write(_WorkerTimers())
        self._root_timers = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_TimerState())))
        self._words = unsafe_alloc[_PoolWords](1, alignment=64)
        self._words.unsafe_write(_PoolWords())
        self.max_blocked = max_blocking_threads
        self._blocking_idle = blocking_idle_timeout.to_nanoseconds()
        self._stack_bytes = stack_bytes

    def __deinit__(deinit self):
        # Pending timers keep their registries, and so their tasks, alive (a
        # cycle once a task holds the registry). Take them out first, then
        # the rings, while every heap and poller still exists: destroying a
        # task may cancel its deadline or release its descriptor registration
        # on any worker. Only then destroy the heaps and the pollers.
        var pending = List[_Waker]()
        for i in range(self._workers):
            var heap = self.opened_heap(i)
            if not heap:
                continue
            while True:
                var timer = heap.value()[].poll_expired(UInt64.MAX)
                if not timer:
                    break
                pending.append(timer.take())
        pending.clear()
        # Closing the thread cache joins any thread it still has, before the
        # slots, heaps and pollers go (`close_blocking` normally did already).
        var blockers = self._words[].blockers.load[ordering=Ordering.ACQUIRE]()
        if blockers:
            var owned = Pointer[_Blockers, MutUntrackedOrigin](unsafe_from_address=blockers)
            owned.unsafe_deinit_pointee()
            owned.unsafe_free()
        var pollers = List[Int]()
        for i in range(self._workers):
            var slot = self._slots.unsafe_offset(i)
            pollers.append(slot[].poller.load[ordering=Ordering.ACQUIRE]())
            slot.unsafe_deinit_pointee()
        self._slots.unsafe_free()
        for i in range(self._workers):
            self._heaps.unsafe_offset(i).unsafe_deinit_pointee()
        self._heaps.unsafe_free()
        for address in pollers:
            if address:
                var poller = Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)
                poller.unsafe_deinit_pointee()
                poller.unsafe_free()
        self._words.unsafe_deinit_pointee()
        self._words.unsafe_free()

    @always_inline
    def workers(self) -> Int:
        return self._workers

    @always_inline
    def _slot(self, index: Int) -> Pointer[_WorkerSlot, MutUntrackedOrigin]:
        return self._slots.unsafe_offset(index)

    @always_inline
    def _heap(self, index: Int) -> Pointer[_TimerHeapOf, MutUntrackedOrigin]:
        """Worker `index`'s open timer heap: owner operations on its thread only, `cancel` and `steal_into` from any."""
        return Pointer(to=self._heaps.unsafe_offset(index)[].heap.value()).unsafe_origin_cast[MutUntrackedOrigin]()

    def opened_heap(self, index: Int) -> Optional[Pointer[_TimerHeapOf, MutUntrackedOrigin]]:
        """Worker `index`'s timer heap if it was opened; from any thread."""
        if self._heaps.unsafe_offset(index)[].opened.load[ordering=Ordering.ACQUIRE]() == 0:
            return None
        return Optional(self._heap(index))

    def _own_heap(self, index: Int) -> Pointer[_TimerHeapOf, MutUntrackedOrigin]:
        """Worker `index`'s timer heap, opened on first use; on that worker's thread only."""
        var timers = self._heaps.unsafe_offset(index)
        if timers[].opened.load[ordering=Ordering.RELAXED]() == 0:
            timers[].heap = Optional(_TimerHeapOf())
            timers[].opened.store[ordering=Ordering.RELEASE](1)
        return self._heap(index)

    def dispatch(self, target: Int) -> _Dispatch:
        """This pool's hook for a root's scheduler; `target` is the pool's address."""
        return _Dispatch(target, _pool_push, _pool_notify, _pool_shard, _pool_foreign, _pool_timer, _pool_cancel_timer)

    def scheduler(self, target: Int) -> _Scheduler:
        """A fresh root scheduler whose tasks and timers go to this pool."""
        return _Scheduler(self.dispatch(target), self._root_timers, self._workers)

    # ===--- Hook (c): shutdown ---=== #

    @always_inline
    def closing(self) -> Bool:
        """Hook (c): whether `shutdown` began; workers leave their loops."""
        return self._words[].closing.load[ordering=Ordering.SEQUENTIAL]() != 0

    def shutdown(self):
        """Hook (c): stop every worker, join every started thread, and drop what is left queued.

        Called once, by the pool's owner, on a thread that is not one of the
        pool's started workers, after every root it ran completed (a pool
        owned by a `Runtime` calls `shutdown_on_worker` on its own workers).
        Workers never started are claimed so that no late notifier starts
        them; a start already claimed is waited for, then interrupted with
        the rest. Every root's scheduler is closed first (`_RootHandle.take`),
        which waits for the foreign wakes still in flight and drops later ones
        (`_Dispatch`). Each worker empties its ring as it leaves
        (`drain_on_shutdown`), and the external queue is emptied here, after
        the joins, so no queued task is destroyed inside the pool's destructor.
        """
        self._stop_workers(-1)
        # Hook (b): stop the thread cache before joining the started workers,
        # which may wait in it after a handed-off call.
        self.close_blocking()
        for i in range(self._workers):
            var slot = self._slot(i)
            if slot[].thread:
                # Joins the worker, then releases its boot state.
                _ = slot[].thread.take()
        self._drain_external()

    def shutdown_on_worker(self, var owner: ArcPointer[_Pool], index: Int):
        """Hook (c): shut down from worker `index`, whose thread cannot join itself.

        The pool's owner was dropped by a task run on one of its own workers.
        Stops and joins every other worker, detaches this one's thread, and
        hands it `owner`, the pool's last reference: the worker finishes its
        current task run, sees `closing`, leaves its loop, drains its ring,
        and its thread destroys the pool last (`_worker_entry`), as a
        `BlockingPool` worker that drops its pool's last copy does.
        """
        self._stop_workers(index)
        # Hook (b): close the thread cache first, as `shutdown` does; a cache
        # thread running this worker is detached by the close, not joined.
        self.close_blocking()
        for i in range(self._workers):
            if i == index:
                continue
            var slot = self._slot(i)
            if slot[].thread:
                _ = slot[].thread.take()
        var own = self._slot(index)
        if own[].thread:
            # The thread's body read its boot state only before its loop.
            _ = own[].thread.take().detach()
        own[].keep = Optional(owner^)

    def _stop_workers(self, current: Int):
        """Publish `closing`, claim the workers never started, and interrupt the others but `current`."""
        self._words[].closing.store[ordering=Ordering.SEQUENTIAL](1)
        for i in range(self._workers):
            if self.parking.stop(i) or i == current:
                continue
            self.parking.wait_unparked(i)
            var address = self._slot(i)[].poller.load[ordering=Ordering.SEQUENTIAL]()
            if address:
                Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)[].interrupt()

    def _drain_external(self):
        """Drop every task left on the external queue, on the calling thread."""
        var random = _Random(UInt64(monotonic()))
        while True:
            var entry = self.external.pop(random)
            if not entry:
                break
            _ = entry.take()

    def blockers(self) -> Pointer[_Blockers, MutUntrackedOrigin]:
        """Hook (b): the pool's thread cache and counts, made on first use.

        Installed with one compare-exchange from 0, ACQUIRE_RELEASE on
        success, so its construction is visible to every reader; readers and
        a losing installer load ACQUIRE and see the winner's, and the loser
        drops its candidate, which started no thread. Freed with the pool.
        """
        var word = Pointer(to=self._words[].blockers).unsafe_origin_cast[MutUntrackedOrigin]()
        var address = word[].load[ordering=Ordering.ACQUIRE]()
        if address == 0:
            var candidate = unsafe_alloc[_Blockers](1, alignment=64)
            # Live cache threads stay below the workers plus the cap: one is
            # started only when none is idle, so every live one runs a slot
            # (at most `workers`) or a handed-off call (at most the cap).
            candidate.unsafe_write(_Blockers(self._workers + self.max_blocked, self._blocking_idle))
            var expected = 0
            if word[].compare_exchange[success_ordering=Ordering.ACQUIRE_RELEASE, failure_ordering=Ordering.ACQUIRE](expected, Int(candidate)):
                address = Int(candidate)
            else:
                candidate.unsafe_deinit_pointee()
                candidate.unsafe_free()
                address = expected
        return Pointer[_Blockers, MutUntrackedOrigin](unsafe_from_address=address)

    def close_blocking(self):
        """Hook (b): stop the thread cache and join the threads it started; `shutdown` calls it.

        Called after shutdown's interrupt loop and before it joins the started
        workers (`slot.thread`): a cache thread running a slot sees `closing`
        and leaves; an idle one, including a started worker that offered
        itself after a call, is woken and exits. Every handed-off call has
        returned by then, since each root's finish waits for its calls.
        Idempotent, and one load for a pool that never handed off; the pool's
        destruction closes the cache again.
        """
        var address = self._words[].blockers.load[ordering=Ordering.ACQUIRE]()
        if address:
            Pointer[_Blockers, MutUntrackedOrigin](unsafe_from_address=address)[].owner.core[].close()

    def drain_on_shutdown(self, slot: Pointer[_WorkerSlot, MutUntrackedOrigin]):
        """Hook (c): a worker leaving at shutdown drops the entries left on its ring, on its own thread.

        Its owner shuts the pool down only after every root it ran completed,
        and a root completes only after its fibers, so an entry left here is a
        stale wake of a finished task. Dropping it on the worker keeps its
        destruction out of the pool's destructor and off the thread that drops
        the pool.
        """
        var queue = Pointer(to=slot[].queue).unsafe_origin_cast[MutUntrackedOrigin]()
        while True:
            var entry = queue[].dequeue()
            if not entry:
                break
            _ = entry.take()

    # ===--- Hook (a): timers ---=== #

    def fire_timers(self, now: Instant) -> Int:
        """Hook (a): fire the running worker's due timers and ready descriptors; returns how many woke something.

        Called on the worker's own thread, every 61 iterations and before it
        parks, and the woken tasks land on its ring. First removes nodes
        canceled by other threads once they reach half the heap. Each waker
        fires after the heap call that took it returned, so no heap operation
        is in progress while it runs. A worker with armed descriptor
        registrations then checks its poller without waiting, as Cats
        Effect's worker does, so a busy worker still reports readiness.
        """
        var current = self.key.get()
        if not current:
            return 0
        var slot = Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)
        var fired = 0
        var opened = self.opened_heap(slot[].index)
        if opened:
            var heap = opened.value()
            heap[].pack_if_needed()
            var key = _deadline_ticks(now)
            while True:
                var timer = heap[].poll_expired(key)
                if not timer:
                    break
                if timer.value().fire():
                    fired += 1
        var address = slot[].poller.load[ordering=Ordering.RELAXED]()
        if address:
            var poller = Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)
            if poller[].needs_poll():
                var ready = List[Signal]()
                try:
                    _ = poller[].poll_deferred(Optional(Duration()), ready)
                except error:
                    abort(String("fp.effects: a work-stealing worker's poller failed: ", error))
                for signal in ready:
                    signal.notify()
                fired += len(ready)
        return fired

    def next_deadline(self) -> Optional[Instant]:
        """Hook (a): the running worker's own earliest deadline, its park timeout."""
        var current = self.key.get()
        if not current:
            return None
        var heap = self.opened_heap(Pointer[_WorkerSlot, MutUntrackedOrigin](unsafe_from_address=current)[].index)
        if not heap:
            return None
        var deadline = heap.value()[].next_deadline()
        if not deadline:
            return None
        return Optional(Instant._from_ticks(deadline.value()))

    def steal_timers(self, index: Int, mut random: _Random) -> Int:
        """Hook (a): a searching worker takes other workers' expired timers and fires them here.

        Scans from a random worker, reading each heap's earliest-deadline hint
        before walking it, and takes at most `_STEAL_TIMERS`. Returns how many
        woke a registration; their tasks are on this worker's ring.
        """
        var now = _deadline_ticks(_Clock().now())
        var taken = List[_Waker]()
        var origin = random.below(self._workers)
        for i in range(self._workers):
            var victim = (origin + i) % self._workers
            if victim == index:
                continue
            var heap = self.opened_heap(victim)
            if heap:
                _ = heap.value()[].steal_into(now, taken, _STEAL_TIMERS - len(taken))
            if len(taken) >= _STEAL_TIMERS:
                break
        if not taken:
            return 0
        _ = self._words[].stolen_timers.fetch_add[ordering=Ordering.RELAXED](len(taken))
        var fired = 0
        for timer in taken:
            if timer.fire():
                fired += 1
        return fired

    def stolen_timers(self) -> Int:
        """Diagnostic: timers fired by a worker other than their heap's owner."""
        return self._words[].stolen_timers.load[ordering=Ordering.RELAXED]()

    # ===--- Notification ---=== #

    def notify(self, target: Int, mut random: _Random):
        """Wake a parked worker, or start one, when no worker searches and not all are active."""
        var claimed = self.parking.notify(random)
        if claimed.worker < 0:
            return
        if claimed.start:
            if not self._start(target, claimed.worker):
                return
        else:
            var address = self._slot(claimed.worker)[].poller.load[ordering=Ordering.ACQUIRE]()
            Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)[].interrupt()
        _ = self._words[].delivered_wakes.fetch_add[ordering=Ordering.RELAXED](1)
        self.parking.finish_unpark(claimed.worker)

    def _start(self, target: Int, worker: Int) -> Bool:
        """Start a claimed worker's thread; false, with the worker not started again, when that fails.

        Notifiers run inside wake paths that cannot raise, on any thread, so
        a failed `pthread_create` is not an error: the work stays queued,
        where a running worker finds it (on a per-call run, worker 0, the
        caller, always runs), and a later notifier may try again. Failures
        are counted (`failed_starts`).
        """
        try:
            self._spawn(target, worker)
            return True
        except:
            _ = self._words[].failed_starts.fetch_add[ordering=Ordering.RELAXED](1)
            self.parking.start_failed(worker)
            return False

    def _spawn(self, target: Int, worker: Int) raises OSError:
        """Create a claimed worker's thread and record it in the worker's slot."""
        var thread = OSThread[_Boot](ArcPointer(_Boot(target, worker)), _worker_entry, stack_bytes=self._stack_bytes)
        self._slot(worker)[].thread = Optional(thread^)

    def reclaimed_slots(self) -> Int:
        """Diagnostic: slots the caller as worker 0 took back after a handed-off call (`_SlotClaim`)."""
        return self._words[].reclaimed.load[ordering=Ordering.RELAXED]()

    def delivered_wakes(self) -> Int:
        """Diagnostic: wakes `notify` delivered, each a claimed parked worker interrupted or a worker started."""
        return self._words[].delivered_wakes.load[ordering=Ordering.RELAXED]()

    def failed_starts(self) -> Int:
        """Diagnostic: how many lazy starts could not create their thread."""
        return self._words[].failed_starts.load[ordering=Ordering.RELAXED]()

    def start_all(self, target: Int) raises OSError:
        """Start every worker not yet started, for a runtime whose caller is not a worker.

        Raises:
            OSError: A thread could not be created. The workers started so far
                run; the owner shuts the pool down.
        """
        for i in range(self._workers):
            if not self.parking.start(i):
                continue
            try:
                self._spawn(target, i)
            except error:
                self.parking.start_failed(i)
                raise error^
            self.parking.finish_unpark(i)


    def _has_work(self) -> Bool:
        if not self.external.is_empty():
            return True
        for i in range(self._workers):
            if not self._slot(i)[].queue.is_empty():
                return True
        return False

    # ===--- The worker loop ---=== #

    def enter(self, index: Int):
        """Make the calling thread worker `index` (0 for a per-call `run`'s caller)."""
        self.key.set(Int(self._slot(index)))

    def leave(self):
        """The calling thread stops being a worker."""
        self.key.set(0)

    def run_worker(self, target: Int, index: Int, var searching: Bool, stop: Int) -> Optional[_Job]:
        """Run worker `index` on this thread until shutdown, a hand-off, or `stop` completes.

        `searching` is whether the worker is counted searching (a started or
        woken worker is). `stop` is a root's `_RootDone` address for the
        caller as worker 0, or 0.

        Returns the call handed off during the last run, for the thread to
        run once it left the worker (hook b). With `stop`, the caller runs it
        here and then waits for its root, so it returns None.
        """
        var slot = self._slot(index)
        self.enter(index)
        while True:
            if self.closing() or _finished(stop):
                break
            var found = self._take_lifo(target, slot)
            if not found:
                found = self._find(target, slot, index, searching)
            if found:
                if searching:
                    searching = False
                    if self.parking.transition_from_searching():
                        self.notify(target, Pointer(to=slot[].random).unsafe_origin_cast[MutUntrackedOrigin]()[])
                self._run(slot, found.take())
                # Hook (b): a handed-off worker leaves when its run ends.
                if slot[].retired:
                    break
                continue
            if self.fire_timers(_Clock().now()) > 0:
                continue
            # Empty here, since the slot is taken before `_find`; a parked
            # worker must hold nothing that no other worker can see.
            self._flush_lifo(target, slot)
            searching = self._park(target, slot, index, searching, stop)
        if searching:
            _ = self.parking.transition_from_searching()
        # A retired worker's slot, LIFO slot included, belongs to its
        # replacement: the hand-off flushes the LIFO slot itself.
        if slot[].retired:
            return self._hand_off(target, slot, index, stop)
        self._flush_lifo(target, slot)
        if self.closing():
            self.drain_on_shutdown(slot)
        self.leave()
        return None

    def _hand_off(self, target: Int, slot: Pointer[_WorkerSlot, MutUntrackedOrigin], index: Int, stop: Int) -> Optional[_Job]:
        """Hook (b): give the slot to a replacement thread and return its stashed call.

        The protocol (the scheduler page's "Blocking hand-off"):

        1. The worker's last run ended, so nothing of the slot is in use.
           It is still active and not searching, which the replacement inherits.
        2. This thread leaves (`key` 0) before anything else, so its later
           wakes go to the external queue: the ring keeps one producer.
        3. It takes the call and clears `retired`, the slot's last owner-only
           writes from this thread.
        4. It submits "run slot `index`" to the thread cache, which claims an
           idle thread or starts one. The cache queue's stripe lock (push
           RELEASE, pop ACQUIRE), or `pthread_create`, orders every write to
           the slot here before the replacement's first read.
        5. The caller as worker 0 (`stop`) runs the call, then takes its slot
           back if no cache thread took the job yet (`_SlotClaim`), and runs
           it again until its root completes. A cache thread serves its
           queue only between calls, so when a thread could not be created
           while another was live the job would otherwise wait there, and
           with it the slot's timers and descriptors, until some cache
           thread finished a call. A started worker needs no such
           step: after its call it serves the cache queue (`_serve_adopted`),
           its own job included.
        """
        # The LIFO slot's task goes to the ring, so thieves can take it while
        # the replacement starts.
        self._flush_lifo(target, slot)
        self.leave()
        var blocked = slot[].blocked.take()
        slot[].retired = False
        var blockers = self.blockers()
        var claim = _SlotClaim()
        _submit(blockers[].owner.core, _Job(_Erased(_SlotJob(target, index, claim.copy())), _run_slot, blockers[].slot_jobs))
        if not stop:
            return Optional(blocked^)
        # The caller as worker 0 runs the call with a poller of its own, then
        # takes its slot back if no replacement took it (step 5), or else
        # waits for its root as `_RootHandle.wait` does. Its root has not
        # completed: the call's fiber waits for the call.
        var poller = _open_poller()
        blocked^.execute(_WorkerContext(Pointer(to=poller).unsafe_origin_cast[MutUntrackedOrigin]()))
        _ = poller^
        if claim.take():
            _ = self._words[].reclaimed.fetch_add[ordering=Ordering.RELAXED](1)
            # As a replacement does (`_run_slot`): the slot is active and not
            # searching, so ask to search first. A later hand-off from here
            # recurses into this method, which returns None for `stop`.
            var searching = self.parking.transition_to_searching()
            return self.run_worker(target, index, searching, stop)
        try:
            _wait_done(stop)
        except error:
            abort(String("fp.effects: a worker that handed off could not wait for its root: ", error))
        return None

    def _take_lifo(self, target: Int, slot: Pointer[_WorkerSlot, MutUntrackedOrigin]) -> Optional[_Entry]:
        """The LIFO slot's task, unless it ran `_MAX_LIFO_RUNS` times in a row; then it joins the ring.

        The count resets whenever the worker looks for work elsewhere
        (`_find`), so a ping-pong pair, each waking the other into the slot,
        lets the ring's head run after every `_MAX_LIFO_RUNS` runs.
        """
        if not slot[].lifo:
            slot[].lifo_runs = 0
            return None
        if slot[].lifo_runs < _MAX_LIFO_RUNS:
            slot[].lifo_runs += 1
            return slot[].lifo.take()
        slot[].lifo_runs = 0
        self._flush_lifo(target, slot)
        return None

    def _flush_lifo(self, target: Int, slot: Pointer[_WorkerSlot, MutUntrackedOrigin]):
        """Move the LIFO slot's task, if any, to the back of the ring, where other workers can steal it.

        Owner-only, on the worker's own thread, while it runs no task. A
        worker flushes before it parks and when it leaves its loop, so no
        task waits in the slot of a worker that is not running; the
        blocking hand-off and the shutdown drain see only the ring. Notifies as any push onto
        the worker's own ring while it runs no task does: when the ring then
        holds more than one entry.
        """
        if not slot[].lifo:
            return
        var queue = Pointer(to=slot[].queue).unsafe_origin_cast[MutUntrackedOrigin]()
        var random = Pointer(to=slot[].random).unsafe_origin_cast[MutUntrackedOrigin]()
        queue[].enqueue(slot[].lifo.take(), self.external, random[])
        if queue[].len() > 1:
            self.notify(target, random[])

    def _run(self, slot: Pointer[_WorkerSlot, MutUntrackedOrigin], var task: _Entry):
        """Run one task with a fresh slice, then park, requeue or retire it, as the current-thread executor does."""
        _TaskHeader.begin_run(task)
        slot[].running = True
        var done = _Executor.run_body(task, True)
        slot[].running = False
        _Executor.settle(task, done)

    def _find(self, target: Int, slot: Pointer[_WorkerSlot, MutUntrackedOrigin], index: Int, mut searching: Bool) -> Optional[_Entry]:
        """The next task: own ring, external queue, then a steal while searching."""
        var queue = Pointer(to=slot[].queue).unsafe_origin_cast[MutUntrackedOrigin]()
        var random = Pointer(to=slot[].random).unsafe_origin_cast[MutUntrackedOrigin]()
        slot[].tick += 1
        if slot[].tick % _EXTERNAL_CHECK == 0:
            _ = self.fire_timers(_Clock().now())
            var outside = queue[].enqueue_batch_from(self.external, random[])
            if outside:
                return outside^
        var own = queue[].dequeue()
        if own:
            return own^
        var batch = queue[].enqueue_batch_from(self.external, random[])
        if batch:
            if not queue[].is_empty():
                self.notify(target, random[])
            return batch^
        if not searching:
            searching = self.parking.transition_to_searching()
            if not searching:
                return None
        if self._workers == 1:
            # No other worker to steal from, but the sole worker still takes
            # permission to search, which is never refused to it, so that it
            # parks as a searcher and re-checks the queues. A non-searcher
            # parks without the re-check, which is safe only when a searcher
            # exists; with one worker none does, and a foreign push that
            # found the worker still counted active, just before it parked,
            # notified no one (`wstp_wakes`' one-worker part).
            return None
        # Hook (a): other workers' expired timers first, as Cats Effect does.
        if self.steal_timers(index, random[]) > 0:
            var woken = queue[].dequeue()
            if woken:
                return woken^
        var origin = random[].below(self._workers)
        for i in range(self._workers):
            var victim = (origin + i) % self._workers
            if victim == index:
                continue
            var stolen = self._slot(victim)[].queue.steal_into(queue[])
            if stolen:
                return stolen^
        return None

    def _ensure_poller(self, slot: Pointer[_WorkerSlot, MutUntrackedOrigin]) -> Pointer[_Poller, MutUntrackedOrigin]:
        """The worker's poller, created on its first park and kept until the pool is destroyed."""
        var address = slot[].poller.load[ordering=Ordering.RELAXED]()
        if address == 0:
            var poller = unsafe_alloc[_Poller](1)
            try:
                poller.unsafe_write(_Poller())
            except error:
                poller.unsafe_free()
                abort(String("fp.effects: a work-stealing worker could not open its poller: ", error))
            address = Int(poller)
            # SEQUENTIAL: pairs with shutdown's store of `closing` and its load
            # of this word, against this worker's later load of `closing`.
            slot[].poller.store[ordering=Ordering.SEQUENTIAL](address)
        return Pointer[_Poller, MutUntrackedOrigin](unsafe_from_address=address)

    def _park(self, target: Int, slot: Pointer[_WorkerSlot, MutUntrackedOrigin], index: Int, searching: Bool, stop: Int) -> Bool:
        """Park in the worker's poller until a notifier, a deadline, shutdown or `stop`; returns true (searching) after."""
        var poller = self._ensure_poller(slot)
        if stop:
            _publish_waiter(stop, poller[].wake_hook().target)
        var deadline = self.next_deadline()
        self.parking.prepare_to_park(index)
        if searching:
            if self.parking.transition_to_parked_when_searching():
                # The last searcher re-checks every queue before sleeping.
                if self._has_work():
                    self.notify(target, Pointer(to=slot[].random).unsafe_origin_cast[MutUntrackedOrigin]()[])
        else:
            self.parking.transition_to_parked()
        if not self.closing() and not _completing(stop):
            var timeout: Optional[Duration] = None
            if deadline:
                var now = _Clock().now()
                timeout = Optional(deadline.value().since(now)) if deadline.value() > now else Optional(Duration())
            var ready = List[Signal]()
            try:
                _ = poller[].poll_deferred(timeout, ready)
            except error:
                abort(String("fp.effects: a work-stealing worker's poller failed: ", error))
            for signal in ready:
                signal.notify()
        # A notifier counted this worker active and searching; otherwise it
        # leaves for its own reason (a deadline, shutdown, its root, or a
        # spurious interrupt) and counts itself, as a searcher.
        if not self.parking.after_wake(index):
            self.parking.wake_self(index)
        return True


# ===------------------------------------------------------------------=== #
# Roots on the pool
# ===------------------------------------------------------------------=== #


comptime _RUNNING_ROOT = 0
comptime _COMPLETING = 1
comptime _COMPLETE = 2


struct _RootDone(Movable):
    """A root's completion handshake with the thread waiting for it, on its own line.

    `state` goes from running to completing to complete; `waiter` is the
    address of the waiter's poller wake state, 0 until it first waits.

    - The completer publishes the outcome, stores completing (SEQUENTIAL),
      loads `waiter` (SEQUENTIAL), interrupts it if set, then stores complete
      (RELEASE).
    - The waiter stores `waiter` (SEQUENTIAL), then loads `state`
      (SEQUENTIAL) before it waits, and waits only while it reads running.

    Either the completer sees the waiter's address and interrupts it, or the
    waiter sees completing and does not wait. A waiter leaves only once it
    reads complete (ACQUIRE), after the completer's last use of its address.
    """
    var state: Atomic[Int]
    var waiter: Atomic[Int]
    var _padding: Array[Int, 6]

    def __init__(out self):
        self.state = Atomic(_RUNNING_ROOT)
        self.waiter = Atomic(0)
        self._padding = Array[Int, 6](fill=0)


@always_inline
def _done_at(address: Int) -> Pointer[_RootDone, MutUntrackedOrigin]:
    return Pointer[_RootDone, MutUntrackedOrigin](unsafe_from_address=address)


def _finished(stop: Int) -> Bool:
    return stop != 0 and _done_at(stop)[].state.load[ordering=Ordering.ACQUIRE]() == _COMPLETE


def _completing(stop: Int) -> Bool:
    return stop != 0 and _done_at(stop)[].state.load[ordering=Ordering.SEQUENTIAL]() != _RUNNING_ROOT


def _publish_waiter(stop: Int, wake: Int):
    _done_at(stop)[].waiter.store[ordering=Ordering.SEQUENTIAL](wake)


comptime _WAIT_SPIN_NANOSECONDS = 50_000
"""How long `Runtime.run`'s caller spins, then yields, before it parks (`_spin_for_done`)."""

comptime _WAIT_PROBE = 16
"""After a wait that parked, every this many waits still spin, to notice programs turning short."""


def _spin_for_done(stop: Int, parked_waits: Pointer[Atomic[Int], MutUntrackedOrigin]) -> Bool:
    """Wait for the root at `stop` without parking, for a bounded time; true when it completed.

    A program that completes within the window spares the caller its poller
    and the operating system's wake latency (about 0.1 ms on a VM). The caller
    first reads the state `_UNPARK_SPINS` times, then yields between reads
    until `_WAIT_SPIN_NANOSECONDS` pass, as the unpark paths wait for a short
    step. It is a waiter's busy loop, so a long program would pay the window in
    CPU on every run: `parked_waits` counts the pool's waits that parked in a
    row, and while it is nonzero only every `_WAIT_PROBE`-th wait spins. A
    wait that completed in the window resets it. The word is RELAXED: it
    orders no data, and concurrent callers only perturb the heuristic.
    """
    var streak = parked_waits[].load[ordering=Ordering.RELAXED]()
    if streak != 0 and streak % _WAIT_PROBE != 0:
        _ = parked_waits[].fetch_add[ordering=Ordering.RELAXED](1)
        return False
    var spins = 0
    var deadline = 0
    while not _finished(stop):
        if spins < _UNPARK_SPINS:
            spins += 1
            continue
        var now = Int(monotonic())
        if deadline == 0:
            deadline = now + _WAIT_SPIN_NANOSECONDS
        elif now >= deadline:
            _ = parked_waits[].fetch_add[ordering=Ordering.RELAXED](1)
            return False
        sleep(0.0)
    if streak != 0:
        parked_waits[].store[ordering=Ordering.RELAXED](0)
    return True


def _wait_done(stop: Int) raises OSError:
    """Park the calling thread, which is not one of the pool's workers, until the root at `stop` completes.

    Raises:
        OSError: The waiter's poller could not be opened or failed.
    """
    if _finished(stop):
        return
    var poller = _Poller()
    _publish_waiter(stop, poller.wake_hook().target)
    while True:
        var state = _done_at(stop)[].state.load[ordering=Ordering.SEQUENTIAL]()
        if state == _COMPLETE:
            break
        if state == _COMPLETING:
            sleep(0.0)
            continue
        _ = poller.poll(None)
    # Keep the poller alive past the completer's last interrupt.
    _ = poller^


struct _RootResult[V: Movable & Deinitable, E: Movable & Deinitable](Movable):
    """A pool root's outcome and its completion handshake (`_RootDone`)."""
    var outcome: _OneShot[Outcome[Self.V, Self.E]]
    var done: Pointer[_RootDone, MutUntrackedOrigin]

    def __init__(out self):
        self.outcome = _OneShot[Outcome[Self.V, Self.E]]()
        self.done = unsafe_alloc[_RootDone](1, alignment=64)
        self.done.unsafe_write(_RootDone())

    def __deinit__(deinit self):
        self.done.unsafe_deinit_pointee()
        self.done.unsafe_free()

    def complete(self, var outcome: Outcome[Self.V, Self.E]):
        """Publish the root's outcome and wake its waiter; from the worker that finished it."""
        if self.outcome.put(outcome^):
            abort("fp.effects: a pool root completed twice")
        self.done[].state.store[ordering=Ordering.SEQUENTIAL](_COMPLETING)
        var waiter = self.done[].waiter.load[ordering=Ordering.SEQUENTIAL]()
        if waiter:
            _interrupt_at(waiter)
        self.done[].state.store[ordering=Ordering.RELEASE](_COMPLETE)


trait _RootSink(Movable, Deinitable):
    """Where a pool root's outcome goes, on the worker that finishes the root.

    `_Waited` publishes it for a thread waiting on a `_RootHandle`. A detached
    root (`Runtime`'s execution-context regions) has no waiter: its sink
    releases the root itself (`_release_root`) and delivers the outcome.
    """
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable

    def complete(mut self, var outcome: Outcome[Self.Value, Self.Error], scheduler: ArcPointer[_Scheduler]):
        """Take the finished root's outcome; `scheduler` is the root's."""
        ...


struct _Waited[V: Movable & Deinitable, E: Movable & Deinitable](_RootSink):
    """The sink of a root a thread waits for (`_RootHandle`)."""
    comptime Value = Self.V
    comptime Error = Self.E
    var result: ArcPointer[_RootResult[Self.V, Self.E]]

    def __init__(out self, var result: ArcPointer[_RootResult[Self.V, Self.E]]):
        self.result = result^

    def complete(mut self, var outcome: Outcome[Self.V, Self.E], scheduler: ArcPointer[_Scheduler]):
        self.result[].complete(outcome^)


struct _PoolRoot[P: Machine, S: _RootSink](Movable):
    """A root program as an ordinary task body, so that any worker may run it."""
    var slot: _Slot[Self.P, Self.P.Value, Self.P.Error]
    var context: IOContext[Self.P.Error]
    var sink: Self.S

    def __init__(out self, var slot: _Slot[Self.P, Self.P.Value, Self.P.Error], var context: IOContext[Self.P.Error], var sink: Self.S):
        self.slot = slot^
        self.context = context^
        self.sink = sink^


def _run_root[P: Machine, S: _RootSink](mut body: _Erased, fresh: Bool) -> Bool:
    comptime assert S.Value == P.Value and S.Error == P.Error
    ref root = body.pointer[_PoolRoot[P, S]]()[]
    if fresh:
        root.context._budget.value()[].refill()
    _ = _tick(root.slot, root.context)
    if not root.slot.done():
        return False
    var scheduler = root.context._runtime.value().scheduler()
    root.sink.complete(rebind_var[Outcome[S.Value, S.Error]](root.slot.take_outcome()), scheduler)
    return True


def _release_root(scheduler: ArcPointer[_Scheduler]):
    """Release what a completed root's scheduler shares: its blocking calls, queues, context and poller.

    Once per root, after it completed: by the thread that waited for it
    (`_RootHandle.take`), or by a detached root's sink on the worker that
    finished it. Either may run while that worker still settles the root's
    task, which touches only the task's registry.
    """
    _finish_blocking(scheduler)
    scheduler[].shutdown()
    _finish_root_poller(scheduler)


struct _RootHandle[V: Movable & Deinitable, E: Movable & Deinitable](Movable):
    """A root submitted to a pool: wait for it, then take its outcome."""
    var result: ArcPointer[_RootResult[Self.V, Self.E]]
    var scheduler: ArcPointer[_Scheduler]

    def __init__(out self, var result: ArcPointer[_RootResult[Self.V, Self.E]], var scheduler: ArcPointer[_Scheduler]):
        self.result = result^
        self.scheduler = scheduler^

    def done_address(self) -> Int:
        """The completion word a waiting worker 0 stops on (`run_worker`'s `stop`)."""
        return Int(self.result[].done)

    def finished(self) -> Bool:
        return _finished(self.done_address())

    def wait(self) raises OSError:
        """Park the calling thread, which is not one of the pool's workers, until the root completes.

        Raises:
            OSError: The waiter's poller could not be opened or failed.
        """
        _wait_done(self.done_address())

    def wait(self, pool: _Pool) raises OSError:
        """Wait on the calling thread, which is not one of `pool`'s workers, until the root completes.

        A short program is waited for by spinning, then yielding, for a
        bounded time; otherwise the thread parks (`_spin_for_done`).

        Raises:
            OSError: The waiter's poller could not be opened or failed.
        """
        var parked_waits = Pointer(to=pool._words[].parked_waits).unsafe_origin_cast[MutUntrackedOrigin]()
        if _spin_for_done(self.done_address(), parked_waits):
            return
        _wait_done(self.done_address())

    def take(deinit self) -> Outcome[Self.V, Self.E]:
        """The completed root's outcome, after releasing what its scheduler shares, on this thread."""
        if not self.finished():
            abort("fp.effects: a pool root's outcome was taken before it completed")
        _release_root(self.scheduler)
        var outcome = self.result[].outcome.take()
        if not outcome:
            abort("fp.effects: a pool root completed without an outcome")
        return outcome.take()


def _submit_root[P: Machine](pool: ArcPointer[_Pool], var program: P, token: CancellationToken, config: IORuntimeConfig, shared_snapshots: Bool = False) -> _RootHandle[P.Value, P.Error]:
    """Make `program` a root task of `pool` and queue it: on the current worker's ring, or externally.

    With `shared_snapshots`, the root's fiber table may be snapshotted from
    any thread (`Runtime.fibers`), which it allows before it is queued.
    """
    var scheduler = _root_scheduler(pool, shared_snapshots)
    var result = ArcPointer(_RootResult[P.Value, P.Error]())
    _queue_root(scheduler, program^, token, config, _Waited[P.Value, P.Error](result.copy()))
    return _RootHandle[P.Value, P.Error](result^, scheduler^)


def _root_scheduler(pool: ArcPointer[_Pool], shared_snapshots: Bool) -> ArcPointer[_Scheduler]:
    """A fresh root scheduler on `pool`, whose fiber table is shared when asked (`_submit_root`)."""
    var scheduler = ArcPointer(pool[].scheduler(Int(Pointer(to=pool[]))))
    if shared_snapshots:
        scheduler[].share_snapshots()
    return scheduler^


def _queue_root[P: Machine, S: _RootSink](scheduler: ArcPointer[_Scheduler], var program: P, token: CancellationToken, config: IORuntimeConfig, var sink: S):
    """Queue `program` as the root of `scheduler`, a pool root's scheduler; its outcome goes to `sink`.

    Whatever the root's owner installs on the scheduler, such as its
    execution context, must be installed before this call.
    """
    comptime assert S.Value == P.Value and S.Error == P.Error
    var runtime = _Runtime(scheduler=scheduler, fiber=0)
    var context = IOContext[P.Error](token.copy(), False)
    context._runtime = Optional(runtime.copy())
    context._budget = Optional(ArcPointer(_Budget(config.auto_yield_threshold, config.cancelation_check_threshold, config.report_unhandled_fiber_errors, config.reporter, _Registrations(scheduler))))
    _install_blocking(scheduler, config.blocking_pool)
    var slot = _Slot[P, P.Value, P.Error](program^)
    slot.prepare(context)
    var task = ArcPointer(_TaskHeader(_Erased(_PoolRoot[P, S](slot^, context^, sink^)), _run_root[P, S]))
    task[].registry = Optional(runtime.copy())
    # The root's registration is ready, so installing the hook queues it.
    runtime.attach(task)


def _run_pooled[P: Machine](var program: P, token: CancellationToken, config: IORuntimeConfig, workers: Int) -> Outcome[P.Value, P.Error]:
    """Run a program on a pool made for this call, with the calling thread as worker 0.

    The private entry point of the work-stealing profile, which
    `Runtime` and `run` wrap. Other workers start only when there is work to
    steal, so a program that never starts a fiber starts no thread. Returns
    when the root completes, after joining every thread it started.
    """
    var pool: ArcPointer[_Pool]
    try:
        pool = ArcPointer(_Pool(workers, 1, max_blocking_threads=config.max_blocking_threads, blocking_idle_timeout=config.blocking_idle_timeout))
    except error:
        abort(String("fp.effects: could not create a work-stealing pool: ", error))
    var target = Int(Pointer(to=pool[]))
    pool[].enter(0)
    var handle = _submit_root(pool, program^, token, config)
    _ = pool[].run_worker(target, 0, False, handle.done_address())
    # Close the root's scheduler, waiting for foreign wakes in flight, before
    # the pool stops and is freed.
    var outcome = handle^.take()
    pool[].shutdown()
    return outcome^
