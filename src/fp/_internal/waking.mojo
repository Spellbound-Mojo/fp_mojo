"""Generation-checked wake registries and the scheduling state of tasks.

A `_Runtime` is the wake registry of one task: a tree of generation-checked
nodes behind one lock, one per execution slot of that task, so wakes for
different tasks never contend. Ready siblings form intrusive FIFO lists, and a
wake propagates readiness up to the registry's root node. When the root's list
becomes non-empty, the registry's wake hook schedules the task that owns it.

A task is a `_TaskHeader`: an atomic scheduling state (idle, scheduled,
running, notified while running, done) and its owned, erased body, which this
module never runs. The `_Scheduler`, shared by every registry under one root,
holds the ready queue, the timer heap, the host notifier, the count of live
external registrations, and the lock-free diagnostic slots of live fibers.
Wakes may arrive from any thread. On the current-thread profile everything
else is confined to the thread that drives the root; on the work-stealing
profile the scheduler's `_Dispatch` hands woken tasks and timers to the pool
(`fp.effects._async.pool`), and tasks run on its workers, one at a time each.

Objects reached from several threads at once (`_Scheduler`, a header's
state) are used only through immutable `self`, and their atomics and mutable
state live in separate allocations behind pointers. A `mut` borrow is
exclusive in Mojo, so the compiler may assume nothing else touches the
borrowed struct during the call; an atomic stored inline in a struct that
several threads borrow mutably can lose concurrent updates. Lock-guarded
state lives in `_Cell`s, reached through their own pointers.

Where each cross-thread operation's ordering is documented:

- A task's scheduling state: `_TaskHeader`.
- The scheduler's words (`polling`, `closed`, `in_flight`, `live_timers`,
  `registrations`, `blocking`, `poller`, `wake_target`, `notifier`):
  `_Scheduler`, with the notify-or-close handshake on `notify_host`.
- The external-registration count: `_Registrations`.
- Registries (`_Runtime`, `_Waker`), `Signal`, the ready queue, the root's
  timer heap and the manual clock: each behind its own `_Cell` lock taken
  with `_lock_metadata`, whose acquire and release are SEQUENTIAL
  (`fp._internal.cells`). Every wake takes its registry's lock before the
  task's wake hook (`_schedule`), so the lock orders wakes against a run's
  end (`_Runtime.park`). `Signal.notify` copies its wakers under its lock and
  wakes them after releasing it; hook subscriptions fire under it.
- The fiber slots: `fp._internal.fiber_slots`.
"""
from std.atomic import Atomic, Ordering
from std.collections import BinaryHeap, Deque
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import monotonic, sleep
from .cells import _Cell, _lock_metadata
from .fiber_slots import _FiberSlots
from .erased import _Erased
from .os import realtime_nanoseconds
from .time import Instant, SystemTime


def _next_generation(value: UInt64) -> UInt64:
    if value == UInt64.MAX:
        abort("wake generation exhausted")
    return value + 1


struct _Clock(Copyable):
    var _manual: Optional[ArcPointer[_Cell[Instant]]]

    def __init__(out self):
        self._manual = None

    @staticmethod
    def _valid_manual(now: Int) -> Bool:
        return now >= 0

    @staticmethod
    def manual(now: Int = 0) -> Self:
        if not Self._valid_manual(now):
            abort("manual clock must be nonnegative")
        var clock = Self()
        clock._manual = Optional(ArcPointer(_Cell(Atomic(UInt8(0)), Optional(Instant._from_ticks(UInt64(now))))))
        return clock^

    def now(self) -> Instant:
        if self._manual:
            var guard = _lock_metadata(self._manual.value())
            return guard.cell[].slot.value().copy()
        return Instant._from_ticks(UInt64(monotonic()))

    def real_now(self) -> SystemTime:
        # The system clock reads CLOCK_REALTIME. A manual clock's wall time is
        # the epoch plus its monotonic reading, as in Cats Effect's TestControl,
        # so both clocks measure the same virtual elapsed time.
        if not self._manual:
            return SystemTime.nanoseconds(realtime_nanoseconds())
        var now = self.now()
        if now._high != 0 or now._low > UInt64(Int.MAX):
            abort("manual clock exceeds SystemTime range")
        return SystemTime.nanoseconds(Int(now._low))

    def _try_advance_to(self, now: Instant) -> Bool:
        if not self._manual:
            return False
        var guard = _lock_metadata(self._manual.value())
        if now < guard.cell[].slot.value():
            return False
        guard.cell[].slot = Optional(now.copy())
        return True

    def advance_to(self, now: Instant):
        if not self._try_advance_to(now):
            abort("only a manual clock can advance monotonically")


@fieldwise_init
struct _Ticket(Copyable):
    var index: Int
    var generation: UInt64


@fieldwise_init
struct _TimerHandle(Copyable):
    """Where a deadline waits on a work-stealing pool: its worker's heap and its ticket there.

    `worker` is -1 when no pool timer is pending. Stored in the registry node
    under the registry's lock, which is how a ticket reaches another thread
    (`fp.effects._async.pool`'s timer hooks).
    """
    var worker: Int
    var ticket: _Ticket

    @staticmethod
    def none() -> Self:
        return Self(-1, _Ticket(0, 0))


struct _Node(Copyable):
    var generation: UInt64
    var epoch: UInt64
    var active: Bool
    var parent: Int
    var tag: Int
    var queued: Bool
    var own_ready: Bool
    var previous: Int
    var next: Int
    var first: Int
    var last: Int
    var children: Int
    var deadline: Optional[Instant]
    # The pending deadline's place in a pool worker's heap; none on the current-thread profile.
    var timer: _TimerHandle

    def __init__(out self, generation: UInt64, parent: Int, tag: Int):
        self.generation = generation
        self.epoch = 1
        self.active = True
        self.parent = parent
        self.tag = tag
        self.queued = False
        self.own_ready = False
        self.previous = -1
        self.next = -1
        self.first = -1
        self.last = -1
        self.children = 0
        self.deadline = None
        self.timer = _TimerHandle.none()


@fieldwise_init
struct _Timer(Copyable, Comparable):
    var deadline: Instant
    var sequence: UInt64
    # The registry node to wake, and the wait epoch the deadline belongs to.
    var target: _Waker

    # BinaryHeap is a max-heap; reverse time and insertion order.
    def __lt__(self, other: Self) -> Bool:
        return self.deadline > other.deadline or (self.deadline == other.deadline and self.sequence > other.sequence)
    def __eq__(self, other: Self) -> Bool:
        return self.deadline == other.deadline and self.sequence == other.sequence
    def __ne__(self, other: Self) -> Bool:
        return not self == other
    def __le__(self, other: Self) -> Bool:
        return self < other or self == other
    def __gt__(self, other: Self) -> Bool:
        return other < self
    def __ge__(self, other: Self) -> Bool:
        return other <= self


# Task scheduling states. Transitions: idle -> scheduled by a wake (the hook),
# scheduled -> running by the executor that pops the task, running -> notified
# by a wake during the run, running or notified -> idle or scheduled when the
# run parks, and running -> done when the task finishes.
comptime _IDLE = UInt8(0)
comptime _SCHEDULED = UInt8(1)
comptime _RUNNING = UInt8(2)
comptime _NOTIFIED = UInt8(3)
comptime _DONE = UInt8(4)

comptime _TaskRun = def(mut _Erased, Bool) thin -> Bool
"""Run a task body once; true when the task has finished.

The flag asks the body to refill its own transition slice first: a
work-stealing worker gives every task run a full slice (the executor's
`begin_run` hook), while the current-thread executor refills one shared slice
per turn and passes false.
"""


def _no_run(mut body: _Erased, fresh: Bool) -> Bool:
    abort("the root task is run by its driver")


struct _TaskHeader(Movable):
    """A task: its atomic scheduling state and its owned, erased body.

    A queue entry is the right to run a task: the state is scheduled exactly
    while one entry exists, and only the executor that popped it touches the
    body, while the state is running or notified. Between runs the body stays
    here, so moving the entry between workers moves that right with it.

    The state word sits inline, in the header's own `ArcPointer` allocation,
    as the reference count beside it does: one allocation per task. Wakes on
    other threads compare-and-swap it while an executor uses the header, so
    nothing ever borrows a shared header as `self`, mutably or not (Mojo marks
    such a borrow exclusive or read-only, and an inline atomic reached through
    it may lose concurrent updates or be read stale). Every access goes through
    the task's `ArcPointer` and `state_of`, an untracked pointer to the word.
    The other fields belong to whoever holds the right to run the task.

    Memory ordering of each operation on the state word:

    - `begin_run` stores RUNNING RELAXED. The queue that handed over the
      entry (a lock, or a ring's RELEASE tail store and ACQUIRE load) already
      ordered the body's writes before the run, and no reader acts on
      RUNNING alone: a waker that reads it still decides under the registry's
      lock.
    - `_schedule` (a wake, under the registry's lock) loads ACQUIRE and moves
      IDLE to SCHEDULED, or RUNNING to NOTIFIED, with ACQUIRE_RELEASE
      compare-exchanges (ACQUIRE on failure, which reloads). The acquire
      pairs with the RELEASE store of the park that made the task idle; the
      release orders the waker's writes before the push that hands the task
      to its executor.
    - `_Runtime.park` (a run's end, under the same lock) stores SCHEDULED or
      IDLE with RELEASE, publishing the run's writes to the next run. Wakes
      and the park take one lock, so a wake lands either before the park's
      check, which requeues the task, or after it, and finds the task idle.
    - `finish` stores DONE with RELEASE before it destroys the body; `done`
      and `runnable` load ACQUIRE, so a reader that sees DONE sees the
      finished run's writes.
    - Snapshots load the word ACQUIRE through the address published in the
      fiber slots (`fp._internal.fiber_slots`).
    """
    var state: Atomic[UInt8]
    # The executor turn in which the task last ran; touched only by the current-thread executor.
    var turn: UInt64
    var body: _Erased
    var run: _TaskRun
    var root: Bool
    # The task's own wake registry, which parks it; cleared when it finishes.
    var registry: Optional[_Runtime]

    def __init__(out self, var body: _Erased, run: _TaskRun):
        self.state = Atomic(_IDLE)
        self.turn = 0
        self.body = body^
        self.run = run
        self.root = False
        self.registry = None

    @staticmethod
    def for_root() -> Self:
        """The header of a root program, which its driver polls directly."""
        var header = Self(_Erased(), _no_run)
        header.root = True
        return header^

    @staticmethod
    @always_inline
    def state_of(task: ArcPointer[Self]) -> Pointer[Atomic[UInt8], MutUntrackedOrigin]:
        """The task's state word, through an untracked pointer into its allocation.

        The address lives as long as the task's last `ArcPointer`; fiber slots
        record it for snapshots (`register_fiber`).
        """
        return Pointer[Atomic[UInt8], MutUntrackedOrigin](unsafe_from_address=Int(Pointer(to=task[].state)))

    @staticmethod
    def begin_run(task: ArcPointer[Self]):
        # The queue that handed over the entry already ordered the body's
        # writes before this point: a lock, or the ring's RELEASE tail store
        # and ACQUIRE load; relaxed suffices for the marker.
        Self.state_of(task)[].store[ordering=Ordering.RELAXED](_RUNNING)

    @staticmethod
    def finish(task: ArcPointer[Self]):
        """Mark the task done and destroy its body now, not when the last reference goes."""
        Self.state_of(task)[].store[ordering=Ordering.RELEASE](_DONE)
        task[].body = _Erased()
        task[].registry = None

    @staticmethod
    def runnable(task: ArcPointer[Self]) -> Bool:
        """Whether the task is scheduled, running, or notified, for diagnostics."""
        var state = Self.state_of(task)[].load[ordering=Ordering.ACQUIRE]()
        return state == _SCHEDULED or state == _RUNNING or state == _NOTIFIED

    @staticmethod
    def done(task: ArcPointer[Self]) -> Bool:
        """Whether the task finished; ACQUIRE pairs with `finish`'s RELEASE store."""
        return Self.state_of(task)[].load[ordering=Ordering.ACQUIRE]() == _DONE


def _schedule(task: ArcPointer[_TaskHeader], scheduler: ArcPointer[_Scheduler]) -> Bool:
    """The wake hook: schedule an idle task, or mark a running one notified.

    Called with the task's registry locked, as every wake and every park take
    that lock. Returns whether the host must be notified.
    """
    # Acquire pairs with the release of the park that made the task idle.
    var word = _TaskHeader.state_of(task)
    var state = word[].load[ordering=Ordering.ACQUIRE]()
    while True:
        if state == _IDLE:
            # Acquire-release: the push publishes the task to the executor.
            if word[].compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.ACQUIRE_RELEASE](state, _SCHEDULED):
                return scheduler[].push(task.copy())
        elif state == _RUNNING:
            if word[].compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.ACQUIRE_RELEASE](state, _NOTIFIED):
                return False
        else:
            # Already scheduled or notified, or done: one entry at most.
            return False


trait _TaskQueue(Movable, Sized):
    """The ready queue's interface: FIFO entries, each the right to run a task.

    The current-thread profile uses `_FifoQueue`; a per-worker lock-free ring
    with an external queue can implement the same interface.
    """
    def push(mut self, var task: ArcPointer[_TaskHeader]):
        """Append a scheduled task."""
        ...

    def pop(mut self) -> Optional[ArcPointer[_TaskHeader]]:
        """Take the oldest scheduled task, if any."""
        ...

    def __len__(self) -> Int:
        """The number of scheduled tasks."""
        ...


struct _FifoQueue(_TaskQueue):
    """A deque of scheduled tasks; its owner guards it with a lock."""
    var tasks: Deque[ArcPointer[_TaskHeader]]

    def __init__(out self):
        self.tasks = Deque[ArcPointer[_TaskHeader]]()

    def push(mut self, var task: ArcPointer[_TaskHeader]):
        self.tasks.append(task^)

    def pop(mut self) -> Optional[ArcPointer[_TaskHeader]]:
        if not len(self.tasks):
            return None
        try:
            return Optional(self.tasks.popleft())
        except:
            return None

    def __len__(self) -> Int:
        return len(self.tasks)


comptime _ReadyQueue = _FifoQueue


struct _Notifier(Movable):
    """The host's erased notifier: called when an external event makes the root runnable."""
    var target: _Erased
    var call: def(mut _Erased) thin

    def __init__(out self, var target: _Erased, call: def(mut _Erased) thin):
        self.target = target^
        self.call = call


struct _TimerState(Movable):
    var heap: BinaryHeap[_Timer]
    var sequence: UInt64

    def __init__(out self):
        self.heap = BinaryHeap[_Timer]()
        self.sequence = 0


@fieldwise_init
struct _FiberView(Copyable):
    """One live fiber's metadata for a driver snapshot."""
    var index: Int
    var owner: Int
    # 0 runnable, 1 suspended, 2 draining.
    var status: Int


@fieldwise_init
struct _WakeHook(Copyable, TrivialRegisterPassable):
    """Wake something this module cannot name: an address and the thin function that wakes it.

    The root's poller lives above this module (`fp.effects._async.polling`),
    so the scheduler and `Signal` reach its interrupt through a hook. `fire`
    must be nonblocking, take no lock and be safe from any thread. The hook
    holds no reference: whoever installs one keeps its target alive until no
    thread can fire it, as `_Scheduler.close` and `_Subscription` ensure.
    """
    var target: Int
    var call: def(Int) thin

    @always_inline
    def fire(self):
        var call = self.call
        call(self.target)


def _no_push(target: Int, var task: ArcPointer[_TaskHeader]) -> Bool:
    abort("a task was pushed through an absent dispatch")


def _no_shard(target: Int) -> Int:
    return 0


def _no_foreign(target: Int) -> Bool:
    return False


def _no_timer(target: Int, deadline: UInt64, var waker: _Waker) -> _TimerHandle:
    abort("a timer was armed through an absent dispatch")


def _no_cancel_timer(target: Int, handle: _TimerHandle):
    pass


@fieldwise_init
struct _Dispatch(Copyable, TrivialRegisterPassable):
    """A work-stealing pool's half of a root's scheduler: an address and thin functions.

    The pool lives above this module (`fp.effects._async.pool`), so a root's
    scheduler reaches it through this hook, as it reaches its poller through
    `_WakeHook`. `target` is 0 on the current-thread profile, where the root's
    own ready queue and host notification serve instead.

    - `push(target, task)` queues a task that was just made scheduled: onto
      the running worker's ring when called on one of the pool's workers,
      otherwise onto the pool's external queue, and returns whether `notify`
      should follow. It is called under the task's registry lock, so it takes
      no lock that a registry's holder may wait on, and never wakes a worker
      itself.
    - `notify(target)` runs after the registry lock is released: it wakes a
      parked worker if no worker is searching and not all are active.
    - `shard(target)` is the running worker's index, or 0 off the pool; it
      picks the fiber-slot shard.

    - `foreign(target)` is whether the calling thread is not one of the
      pool's workers.
    - `timer(target, deadline, waker)` inserts a deadline into the running
      worker's own timer heap and returns where it waits; `cancel_timer`
      cancels it from any thread. Both are called under the registry lock of
      the node that owns the deadline; neither takes a lock or runs a waker.

    Every caller of `push` passes its result to `notify` on the same thread
    after releasing the lock (`_notify`). A wake from a thread outside the
    pool may arrive after its root completed, or complete the root between
    its push and its notify, so the scheduler wraps it in a notify-or-close
    handshake (`_Scheduler.push`, `notify_host`, `close`): the root closes its
    scheduler before its pool shuts down, and a closed scheduler drops the
    push. A push from one of the pool's own workers needs no handshake: a
    running worker keeps the pool alive. The hook holds no reference.
    """
    var target: Int
    var push: def(Int, var ArcPointer[_TaskHeader]) thin -> Bool
    var notify: def(Int) thin
    var shard: def(Int) thin -> Int
    var foreign: def(Int) thin -> Bool
    var timer: def(Int, UInt64, var _Waker) thin -> _TimerHandle
    var cancel_timer: def(Int, _TimerHandle) thin

    @staticmethod
    def none() -> Self:
        return Self(0, _no_push, _no_wake, _no_shard, _no_foreign, _no_timer, _no_cancel_timer)


struct _PaddedCount(Movable):
    """One atomic count alone on a 64-byte line, for words other threads write."""
    var value: Atomic[Int]
    var _padding: Array[Int, 7]

    def __init__(out self):
        self.value = Atomic(0)
        self._padding = Array[Int, 7](fill=0)


struct _SchedulerWords(Movable):
    """The scheduler's cross-thread words, in one 64-byte-aligned allocation.

    `in_flight` and `registrations` are written by foreign threads (wakers and
    dropped callbacks), so each has its own line. The rest are written by the
    driving thread and read by wakers, and share the third line onward.
    Orderings are documented on `_Scheduler`'s accessors.
    """
    var in_flight: _PaddedCount
    var registrations: _PaddedCount
    var polling: Atomic[UInt8]
    var closed: Atomic[UInt8]
    var live_timers: Atomic[Int]
    var blocking: Atomic[Int]
    var context: Atomic[Int]
    var poller: Atomic[Int]
    var wake_target: Atomic[Int]
    var wake_call: def(Int) thin
    var notifier: Optional[_Notifier]

    def __init__(out self):
        self.in_flight = _PaddedCount()
        self.registrations = _PaddedCount()
        self.polling = Atomic(UInt8(0))
        self.closed = Atomic(UInt8(0))
        self.live_timers = Atomic(0)
        self.blocking = Atomic(0)
        self.context = Atomic(0)
        self.poller = Atomic(0)
        self.wake_target = Atomic(0)
        self.wake_call = _no_wake
        self.notifier = None


def _no_wake(target: Int):
    pass


struct _Scheduler(Movable):
    """What every wake registry of one root shares.

    The ready queue, the notifier state, the registration count and the fiber
    slots are safe from any thread. The timer heap is touched only by the
    thread driving the root; its lock is never held while another lock is
    taken, except that the heap's maintenance locks registries, which never
    take the heap's lock. On a work-stealing pool the root's heap stays empty:
    a deadline goes into the running worker's own heap under the registry's
    lock and is canceled from there (`_Dispatch.timer`, `cancel_timer`).

    The atomics live in one allocation (`_SchedulerWords`), reached through an
    untracked pointer and only through immutable `self`; the scheduler is held
    by `ArcPointer`, so the words live exactly as long as it does. Each word's
    ordering:

    - `polling`: stored and loaded SEQUENTIAL, paired with the ready queue
      (see `push` and the driver's poll).
    - `closed` and `in_flight`: SEQUENTIAL on both sides of the
      notify-or-close handshake (`notify_host`, `close`), with a RELEASE
      decrement after a call.
    - `live_timers`: RELAXED; a heuristic bounding the heap's tombstones,
      kept on the current-thread profile only (a pool cancels its timers).
    - `registrations`: RELEASE increments and decrements, ACQUIRE loads
      (`_Registrations`).
    - `blocking`: the root's blocking slot; `blocking_pool` documents it.
    - `context`: 0, or the address of an owned `_Erased` box holding the
      root's execution context (`fp.effects._async.runtime`). Stored RELEASE
      once by the root's owner before the root is queued or driven, loaded
      ACQUIRE by the root's fibers (`context_box`), and taken back to 0 and
      freed by `shutdown`, after the root completed, so no reader remains and
      a scheduler kept alive by a stale waker holds no context.
    - `poller`: the root poller's address, touched only by the driving
      thread; RELAXED (`fp.effects._async.polling`'s root slot).
    - `wake_target`: the root poller's wake hook. `wake_call` is written first,
      then the target is stored RELEASE by the driving thread before it next
      reads the ready queue; `notify_host` loads it ACQUIRE after pushing, so
      either the waker sees the hook or the driver's re-check sees the task.
    - `notifier`: installed before the root is shared and cleared by
      `shutdown` after `close`, so a reader that passed the closed check sees
      it unchanged.
    """
    var ready: ArcPointer[_Cell[_ReadyQueue]]
    # The root's own heap; on the pool profile an empty one its roots share, since workers own theirs.
    var timers: ArcPointer[_Cell[_TimerState]]
    # Live fibers' diagnostic slots, lock-free (`fiber_slots.mojo`).
    var fibers: _FiberSlots
    var words: Pointer[_SchedulerWords, MutUntrackedOrigin]
    # The count of live timers for the heap's tombstone bound (current-thread profile).
    var live: Pointer[Atomic[Int], MutUntrackedOrigin]
    # Fixed before the scheduler is shared; `target` 0 on the current-thread profile.
    var dispatch: _Dispatch

    def __init__(out self):
        """A root's scheduler on the current-thread profile."""
        self.ready = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReadyQueue())))
        self.timers = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_TimerState())))
        self.fibers = _FiberSlots()
        self.words = unsafe_alloc[_SchedulerWords](1, alignment=64)
        self.words.unsafe_write(_SchedulerWords())
        self.live = Pointer(to=self.words[].live_timers).unsafe_origin_cast[MutUntrackedOrigin]()
        self.dispatch = _Dispatch.none()

    def __init__(out self, dispatch: _Dispatch, timers: ArcPointer[_Cell[_TimerState]], shards: Int):
        """A root's scheduler on a work-stealing pool: tasks and timers go to the pool (see `_Dispatch`).

        `timers` is an empty heap the pool shares between its roots, which
        never use it: their deadlines go into the workers' own heaps.
        """
        self.ready = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReadyQueue())))
        self.timers = timers.copy()
        self.fibers = _FiberSlots(shards)
        self.words = unsafe_alloc[_SchedulerWords](1, alignment=64)
        self.words.unsafe_write(_SchedulerWords())
        self.live = Pointer(to=self.words[].live_timers).unsafe_origin_cast[MutUntrackedOrigin]()
        self.dispatch = dispatch

    def __deinit__(deinit self):
        # A root that never shut down, such as a driver dropped unfinished.
        self._drop_context()
        self.words.unsafe_deinit_pointee()
        self.words.unsafe_free()

    @always_inline
    def pooled(self) -> Bool:
        """Whether this root runs on a work-stealing pool."""
        return self.dispatch.target != 0

    @always_inline
    def live_timers(self) -> ref[MutUntrackedOrigin] Atomic[Int]:
        return self.live[]

    @always_inline
    def blocking_word(self) -> Pointer[Atomic[Int], MutUntrackedOrigin]:
        """The root's blocking slot (see `blocking_pool`); lives as long as this scheduler."""
        return Pointer(to=self.words[].blocking).unsafe_origin_cast[MutUntrackedOrigin]()

    def set_context(self, var box: _Erased):
        """Install the root's execution context, once, before the root is queued or driven."""
        var owned = unsafe_alloc[_Erased](1)
        owned.unsafe_write(box^)
        if self.words[].context.load[ordering=Ordering.RELAXED]() != 0:
            abort("fp.effects: a root's execution context was installed twice")
        self.words[].context.store[ordering=Ordering.RELEASE](Int(owned))

    def context_box(self) -> Optional[Pointer[_Erased, MutUntrackedOrigin]]:
        """The root's execution context box, or none; read only by the root's own fibers."""
        var address = self.words[].context.load[ordering=Ordering.ACQUIRE]()
        if address == 0:
            return None
        return Optional(Pointer[_Erased, MutUntrackedOrigin](unsafe_from_address=address))

    def _drop_context(self):
        var address = self.words[].context.load[ordering=Ordering.ACQUIRE]()
        if address == 0:
            return
        self.words[].context.store[ordering=Ordering.RELAXED](0)
        var owned = Pointer[_Erased, MutUntrackedOrigin](unsafe_from_address=address)
        owned.unsafe_deinit_pointee()
        owned.unsafe_free()

    @always_inline
    def poller_word(self) -> Pointer[Atomic[Int], MutUntrackedOrigin]:
        """The root poller's slot, driving thread only (see `polling`); lives as long as this scheduler."""
        return Pointer(to=self.words[].poller).unsafe_origin_cast[MutUntrackedOrigin]()

    def install_notifier(self, var notifier: _Notifier):
        """Install the host notifier before the root is shared with another thread."""
        self.words[].notifier = Optional(notifier^)

    def install_wake(self, hook: _WakeHook):
        """Install the root poller's interrupt, on the driving thread, before it next reads the queue.

        The function is written before the RELEASE store of the target, which
        `notify_host` loads ACQUIRE, so a waker that sees the target calls the
        right function. The driver re-checks the queue after installing.
        """
        self.words[].wake_call = hook.call
        self.words[].wake_target.store[ordering=Ordering.RELEASE](hook.target)

    def registered(self) -> Int:
        """Live external registrations under this root (see `_Registrations`)."""
        return self.words[].registrations.value.load[ordering=Ordering.ACQUIRE]()

    def push(self, var task: ArcPointer[_TaskHeader]) -> Bool:
        """Queue a scheduled task; true when the host must be notified.

        The host is told only when the queue was empty and no poll is running:
        a poll in progress reports the task itself. The sequentially consistent
        load of `polling` after the push pairs with the driver clearing it
        before it reads the queue, so one of the two always sees the task.
        """
        if self.pooled():
            # The pool decides where the task goes; the caller notifies it
            # after releasing the registry lock (`notify_host`).
            var push = self.dispatch.push
            var foreign = self.dispatch.foreign
            if not foreign(self.dispatch.target):
                return push(self.dispatch.target, task^)
            # A foreign wake enters the notify-or-close handshake here and
            # leaves it at the end of `notify_host`; once the root closed
            # this scheduler, its pool may be gone, so the entry is dropped.
            _ = self.words[].in_flight.value.fetch_add[ordering=Ordering.SEQUENTIAL](1)
            if self.words[].closed.load[ordering=Ordering.SEQUENTIAL]() != 0:
                _ = self.words[].in_flight.value.fetch_sub[ordering=Ordering.RELEASE](1)
                return False
            _ = push(self.dispatch.target, task^)
            return True
        var guard = _lock_metadata(self.ready)
        ref queue = guard.cell[].slot.value()
        var was_empty = len(queue) == 0
        queue.push(task^)
        _ = guard^
        return was_empty and self.words[].polling.load[ordering=Ordering.SEQUENTIAL]() == 0

    def pop(self) -> Optional[ArcPointer[_TaskHeader]]:
        var guard = _lock_metadata(self.ready)
        return guard.cell[].slot.value().pop()

    def queued(self) -> Int:
        var guard = _lock_metadata(self.ready)
        return len(guard.cell[].slot.value())

    def set_polling(self, polling: Bool):
        self.words[].polling.store[ordering=Ordering.SEQUENTIAL](UInt8(1) if polling else UInt8(0))

    def notify_host(self):
        """Wake the root: interrupt its poller and call the notifier, unless the driver finished.

        Called from whichever thread made the root runnable while no poll ran
        (`push`). Entering increments `in_flight` before reading `closed`, the
        wake hook or the notifier, and closing sets `closed` before reading
        `in_flight`, both sequentially consistent: either the call sees the
        driver closed, or close sees the call and waits for it, so neither the
        root's poller nor the notifier is used after `close` returns.

        The lost-wake handshake with a parking driver: the waker published the
        task under the queue's lock before this call; the driver installs the
        hook, re-checks the queue under the same lock, and only then parks. If
        the waker's push came first, the driver's re-check finds the task;
        otherwise the hook's RELEASE store happens before this ACQUIRE load, so
        the waker interrupts the poller, and the poller's own handshake
        (`fp.effects._async.polling`) makes the park return.

        On a pool this wakes a parked worker instead (`_Dispatch.notify`). A
        wake from one of the pool's workers takes no handshake, since the
        worker keeps the pool alive, so no word of the root is written by
        every wake; a foreign wake leaves the handshake that `push` entered.
        """
        if self.pooled():
            var notify = self.dispatch.notify
            notify(self.dispatch.target)
            var foreign = self.dispatch.foreign
            if foreign(self.dispatch.target):
                # Leave the handshake `push` entered: the pool's last use.
                _ = self.words[].in_flight.value.fetch_sub[ordering=Ordering.RELEASE](1)
            return
        _ = self.words[].in_flight.value.fetch_add[ordering=Ordering.SEQUENTIAL](1)
        if self.words[].closed.load[ordering=Ordering.SEQUENTIAL]() == 0:
            var target = self.words[].wake_target.load[ordering=Ordering.ACQUIRE]()
            if target != 0:
                _WakeHook(target, self.words[].wake_call).fire()
            if self.words[].notifier:
                ref notifier = self.words[].notifier.value()
                var call = notifier.call
                call(notifier.target)
        # Release: the call happens before close observes the count.
        _ = self.words[].in_flight.value.fetch_sub[ordering=Ordering.RELEASE](1)

    def close(self):
        """Stop waking the host and wait for a call in progress."""
        self.words[].closed.store[ordering=Ordering.SEQUENTIAL](1)
        while self.words[].in_flight.value.load[ordering=Ordering.SEQUENTIAL]() != 0:
            sleep(0.0)

    def shutdown(self):
        """Release what a finished root shares, on the thread that drives it.

        A waker retained by another thread may hold the last reference to a
        registry, and through it to this scheduler, after the root finishes.
        Stale heap entries also refer back to registries, a cycle. Emptying the
        heap, the queue, the fiber table and the notifier here breaks the cycle
        and leaves only plain metadata for another thread to destroy; the host's
        notifier is destroyed here, after `close`.
        """
        self.close()
        if not self.pooled():
            # A pool's root has no heap entries: its workers' heaps hold its
            # deadlines, canceled as their registrations clear.
            var timers = _lock_metadata(self.timers)
            timers.cell[].slot.value().heap = BinaryHeap[_Timer]()
            _ = timers^
        var ready = _lock_metadata(self.ready)
        ready.cell[].slot.value() = _ReadyQueue()
        _ = ready^
        self.words[].notifier = None
        self.words[].wake_target.store[ordering=Ordering.RELAXED](0)
        # The execution context last: dropping it may drop a runtime's copy.
        self._drop_context()

    def push_timer(self, deadline: Instant, var target: _Waker):
        _push_timer(self.timers, self.live, deadline, target^)

    def start_timer(self, deadline: Instant, var target: _Waker) -> _TimerHandle:
        """On a pool: insert a deadline into the running worker's heap, under the registry's lock."""
        var timer = self.dispatch.timer
        return timer(self.dispatch.target, _deadline_ticks(deadline), target^)

    def cancel_timer(self, handle: _TimerHandle):
        """On a pool: cancel a pending deadline from any thread, under the registry's lock."""
        var cancel = self.dispatch.cancel_timer
        cancel(self.dispatch.target, handle)

    def fire_due(self, now: Instant) -> Bool:
        """Fire the earliest live due timer; false when none is due."""
        return _fire_due(self.timers, now)

    def next_deadline(self) -> Optional[Instant]:
        """The earliest live deadline, discarding stale entries above it."""
        return _next_deadline(self.timers)

    def retained_timers(self) -> Int:
        var guard = _lock_metadata(self.timers)
        return len(guard.cell[].slot.value().heap)

    def register_fiber(self, owner: Int, task: ArcPointer[_TaskHeader]) -> Int:
        """Record a live fiber without a lock; returns its slot, from 1.

        The slot holds the address of the task's atomic state, which lives as
        long as the task, and the task releases the slot before it finishes.
        """
        var shard = self.dispatch.shard
        return self.fibers.register(owner, UInt64(Int(_TaskHeader.state_of(task))), shard(self.dispatch.target))

    def set_draining(self, fiber: Int):
        self.fibers.set_draining(fiber)

    def release_fiber(self, fiber: Int):
        var shard = self.dispatch.shard
        self.fibers.release(fiber, shard(self.dispatch.target))

    def share_snapshots(self):
        """Allow `snapshot` from any thread; called before the root is shared (`Runtime`)."""
        self.fibers.share_snapshots()

    def fiber_slots(self) -> Int:
        return self.fibers.high_water()

    def snapshot(self) -> List[_FiberView]:
        """Live fibers in slot order: between polls on the driving thread, or from any thread once `share_snapshots` ran (see `fiber_slots.mojo`)."""
        var views = List[_FiberView]()
        for slot in self.fibers.snapshot():
            var status = 1
            if slot.draining:
                status = 2
            else:
                var state = slot.state
                if state == _SCHEDULED or state == _RUNNING or state == _NOTIFIED:
                    status = 0
            views.append(_FiberView(slot.index, slot.owner, status))
        return views^


def _deadline_ticks(deadline: Instant) -> UInt64:
    """A deadline as a pool heap's key: monotonic nanoseconds, saturated past the low word."""
    if deadline._high != 0:
        return UInt64.MAX
    return deadline._low


def _push_timer(timers: ArcPointer[_Cell[_TimerState]], live: Pointer[Atomic[Int], MutUntrackedOrigin], deadline: Instant, var target: _Waker):
    """Add a deadline to a root's heap, rebuilding it without stale entries past twice the live count plus 32."""
    var guard = _lock_metadata(timers)
    ref state = guard.cell[].slot.value()
    state.sequence = _next_generation(state.sequence)
    state.heap.push(_Timer(deadline.copy(), state.sequence, target^))
    if len(state.heap) > 2 * live[].load[ordering=Ordering.RELAXED]() + 32:
        var retained = BinaryHeap[_Timer]()
        while len(state.heap):
            var timer = state.heap.pop()
            if timer.target.timer_live():
                retained.push(timer^)
        state.heap = retained^


def _fire_due(timers: ArcPointer[_Cell[_TimerState]], now: Instant) -> Bool:
    """Fire the earliest live due timer of a heap; false when none is due.

    The heap's lock is released before the waker takes its registry's lock.
    """
    while True:
        var guard = _lock_metadata(timers)
        ref state = guard.cell[].slot.value()
        if not len(state.heap) or state.heap.peek().deadline > now:
            return False
        var timer = state.heap.pop()
        _ = guard^
        if timer.target.fire():
            return True


def _next_deadline(timers: ArcPointer[_Cell[_TimerState]]) -> Optional[Instant]:
    """The earliest live deadline of a heap, discarding stale entries above it."""
    while True:
        var guard = _lock_metadata(timers)
        ref state = guard.cell[].slot.value()
        if not len(state.heap):
            return None
        if state.heap.peek().target.timer_live():
            return Optional(state.heap.peek().deadline.copy())
        _ = state.heap.pop()


struct _Registrations(Copyable):
    """A root's count of live external registrations (IO.async awaiting completion); copies share it.

    It holds the scheduler, so a callback dropped late, possibly on another
    thread, still finds the count alive. A callback increments it when it
    registers and decrements it when it is dropped, both RELEASE; readers load
    it ACQUIRE (`_Scheduler.registered`), so a zero they read follows every
    dropped registration's last access. It is a count, not a lock: readers
    only decide quiescence.
    """
    var _scheduler: ArcPointer[_Scheduler]

    def __init__(out self, scheduler: ArcPointer[_Scheduler]):
        self._scheduler = scheduler.copy()

    def increment(self):
        _ = self._scheduler[].words[].registrations.value.fetch_add[ordering=Ordering.RELEASE](1)

    def decrement(self):
        _ = self._scheduler[].words[].registrations.value.fetch_sub[ordering=Ordering.RELEASE](1)


struct _ReadyState(Movable):
    var nodes: List[_Node]
    var free: List[Int]
    var active: Int
    var live_timers: Int
    var scheduler: ArcPointer[_Scheduler]
    # The task this registry belongs to, scheduled when the root list fills.
    var hook: Optional[ArcPointer[_TaskHeader]]
    # The owning fiber's diagnostic slot; 0 for a root program.
    var fiber: Int

    def __init__(out self, scheduler: ArcPointer[_Scheduler], fiber: Int):
        self.nodes = List[_Node]()
        self.nodes.append(_Node(1, -1, -1))
        self.free = List[Int]()
        self.active = 0
        self.live_timers = 0
        self.scheduler = scheduler.copy()
        self.hook = None
        self.fiber = fiber

    def valid(self, ticket: _Ticket) -> Bool:
        return ticket.index > 0 and ticket.index < len(self.nodes) and self.nodes[ticket.index].active and self.nodes[ticket.index].generation == ticket.generation

    def unlink(mut self, index: Int):
        if not self.nodes[index].queued:
            return
        var parent = self.nodes[index].parent
        var previous = self.nodes[index].previous
        var following = self.nodes[index].next
        if previous < 0:
            self.nodes[parent].first = following
        else:
            self.nodes[previous].next = following
        if following < 0:
            self.nodes[parent].last = previous
        else:
            self.nodes[following].previous = previous
        self.nodes[index].queued = False
        self.nodes[index].previous = -1
        self.nodes[index].next = -1

    def wake(mut self, var index: Int) -> Bool:
        """Queue a node and its ancestors; returns whether the hook must run.

        Runs the hook itself, under this registry's lock, when the root's list
        was empty; the result says whether the host must be notified.
        """
        var filled = False
        while index > 0:
            var parent = self.nodes[index].parent
            if not self.nodes[index].queued:
                var previous = self.nodes[parent].last
                if parent == 0 and previous < 0:
                    filled = True
                self.nodes[index].previous = previous
                self.nodes[index].next = -1
                if previous < 0:
                    self.nodes[parent].first = index
                else:
                    self.nodes[previous].next = index
                self.nodes[parent].last = index
                self.nodes[index].queued = True
            index = parent
        if filled and self.hook:
            return _schedule(self.hook.value(), self.scheduler)
        return False

    def reconcile(mut self, var index: Int) -> Bool:
        while index > 0:
            if self.nodes[index].own_ready or self.nodes[index].first >= 0:
                return self.wake(index)
            self.unlink(index)
            index = self.nodes[index].parent
        return False

    def clear_timer(mut self, index: Int, fired: Bool = False):
        """Forget a node's pending deadline; on a pool, also cancel it in its worker's heap unless it fired."""
        if self.nodes[index].deadline:
            self.nodes[index].deadline = None
            self.live_timers -= 1
            if self.scheduler[].pooled():
                var handle = self.nodes[index].timer.copy()
                self.nodes[index].timer = _TimerHandle.none()
                if not fired:
                    self.scheduler[].cancel_timer(handle)
            else:
                _ = self.scheduler[].live_timers().fetch_sub[ordering=Ordering.RELAXED](1)


def _notify(notify: Bool, scheduler: ArcPointer[_Scheduler]):
    if notify:
        scheduler[].notify_host()


struct _Runtime(Copyable):
    """One task's wake registry; copies share it."""
    var _cell: ArcPointer[_Cell[_ReadyState]]

    def __init__(out self):
        """A registry with its own scheduler, for a root or a standalone test."""
        self._cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReadyState(ArcPointer(_Scheduler()), 0))))

    def __init__(out self, *, scheduler: ArcPointer[_Scheduler], fiber: Int):
        self._cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReadyState(scheduler, fiber))))

    def scheduler(self) -> ArcPointer[_Scheduler]:
        var guard = _lock_metadata(self._cell)
        return guard.cell[].slot.value().scheduler.copy()

    def fiber(self) -> Int:
        var guard = _lock_metadata(self._cell)
        return guard.cell[].slot.value().fiber

    def fork(self, fiber: Int) -> Self:
        """A fresh registry for another task under the same scheduler."""
        return Self(scheduler=self.scheduler(), fiber=fiber)

    def attach(self, task: ArcPointer[_TaskHeader]):
        """Install the wake hook, scheduling the task now if anything is ready."""
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        state.hook = Optional(task.copy())
        var notify = False
        if state.nodes[0].first >= 0:
            notify = _schedule(task, state.scheduler)
        var scheduler = state.scheduler.copy()
        _ = guard^
        _notify(notify, scheduler)

    def detach(self):
        """Remove the wake hook of a finished task, breaking the reference cycle."""
        var guard = _lock_metadata(self._cell)
        guard.cell[].slot.value().hook = None

    def park(self, task: ArcPointer[_TaskHeader]):
        """End a run: requeue the task if anything in it is ready, else make it idle.

        Decided under this registry's lock, which every wake takes before its
        hook, so a wake either lands before the check and requeues the task or
        after it and finds the task idle. Release publishes the body's writes to
        the next run.
        """
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        var notify = False
        # A notified task whose wake was consumed during the run parks: the list decides.
        if state.nodes[0].first >= 0:
            _TaskHeader.state_of(task)[].store[ordering=Ordering.RELEASE](_SCHEDULED)
            notify = state.scheduler[].push(task.copy())
        else:
            _TaskHeader.state_of(task)[].store[ordering=Ordering.RELEASE](_IDLE)
        var scheduler = state.scheduler.copy()
        _ = guard^
        _notify(notify, scheduler)

    def allocate(self, parent: Optional[_Ticket], tag: Int) -> _Ticket:
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        var parent_index = 0
        if parent:
            if not state.valid(parent.value()):
                abort("task attached to a retired parent")
            parent_index = parent.value().index
        var index = len(state.nodes)
        var generation = UInt64(1)
        if len(state.free):
            index = state.free.pop()
            generation = _next_generation(state.nodes[index].generation)
            state.nodes[index] = _Node(generation, parent_index, tag)
        else:
            state.nodes.append(_Node(generation, parent_index, tag))
        state.nodes[parent_index].children += 1
        state.active += 1
        state.nodes[index].own_ready = True
        var notify = state.wake(index)
        var scheduler = state.scheduler.copy()
        _ = guard^
        _notify(notify, scheduler)
        return _Ticket(index, generation)

    def retire(self, ticket: _Ticket):
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        if not state.valid(ticket):
            abort("task registration retired twice")
        var index = ticket.index
        if state.nodes[index].children:
            abort("parent retired with live child registrations")
        state.unlink(index)
        state.clear_timer(index)
        var parent = state.nodes[index].parent
        state.nodes[parent].children -= 1
        state.nodes[index].active = False
        state.free.append(index)
        state.active -= 1
        var notify = state.reconcile(parent)
        var scheduler = state.scheduler.copy()
        _ = guard^
        _notify(notify, scheduler)

    def begin(self, ticket: _Ticket):
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        if not state.valid(ticket):
            abort("poll of a retired registration")
        state.unlink(ticket.index)
        state.nodes[ticket.index].own_ready = False
        state.clear_timer(ticket.index)
        state.nodes[ticket.index].epoch = _next_generation(state.nodes[ticket.index].epoch)

    def ready(self, ticket: _Ticket) -> Bool:
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        return state.valid(ticket) and state.nodes[ticket.index].queued

    def next_child(self, parent: _Ticket, skip: Int = -1) -> Optional[Int]:
        """The tag of the first ready child, passing over children tagged skip."""
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        if not state.valid(parent):
            return None
        var index = state.nodes[parent.index].first
        while index >= 0 and state.nodes[index].tag == skip:
            index = state.nodes[index].next
        if index < 0:
            return None
        return Optional(state.nodes[index].tag)

    def arm(self, ticket: _Ticket, runnable: Bool, deadline: Optional[Instant]):
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        var index = ticket.index
        if not state.valid(ticket):
            abort("arm of a retired registration")
        var epoch = state.nodes[index].epoch
        var pooled = state.scheduler[].pooled()
        if deadline:
            # A second deadline in one wait epoch replaces the first.
            state.clear_timer(index)
            state.nodes[index].deadline = deadline.copy()
            state.live_timers += 1
            if pooled:
                # The running worker's heap takes no lock and runs no waker,
                # so the handle is stored under this lock, which is what later
                # passes it to a canceling thread.
                state.nodes[index].timer = state.scheduler[].start_timer(deadline.value(), _Waker(self._cell.copy(), ticket.copy(), epoch))
            else:
                _ = state.scheduler[].live_timers().fetch_add[ordering=Ordering.RELAXED](1)
        if runnable:
            state.nodes[index].own_ready = True
        var notify = state.reconcile(index)
        var scheduler = state.scheduler.copy()
        _ = guard^
        if deadline and not pooled:
            # The root's heap may lock registries while it rebuilds, so it is
            # reached after this lock is released.
            scheduler[].push_timer(deadline.value(), _Waker(self._cell.copy(), ticket.copy(), epoch))
        _notify(notify, scheduler)

    def fire_due(self, now: Instant) -> Bool:
        return self.scheduler()[].fire_due(now)

    def next_deadline(self) -> Optional[Instant]:
        return self.scheduler()[].next_deadline()

    def waker(self, ticket: _Ticket) -> _Waker:
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        return _Waker(self._cell.copy(), ticket.copy(), state.nodes[ticket.index].epoch)


@fieldwise_init
struct _Waker(Copyable):
    """Wakes one registration while its wait epoch lasts; safe from any thread."""
    var cell: ArcPointer[_Cell[_ReadyState]]
    var ticket: _Ticket
    var epoch: UInt64

    def wake(self) -> Bool:
        var guard = _lock_metadata(self.cell)
        ref state = guard.cell[].slot.value()
        if not state.valid(self.ticket) or state.nodes[self.ticket.index].epoch != self.epoch:
            return False
        state.nodes[self.ticket.index].own_ready = True
        var notify = state.wake(self.ticket.index)
        var scheduler = state.scheduler.copy()
        _ = guard^
        _notify(notify, scheduler)
        return True

    def timer_live(self) -> Bool:
        """Whether the deadline armed in this epoch is still pending."""
        var guard = _lock_metadata(self.cell)
        ref state = guard.cell[].slot.value()
        return state.valid(self.ticket) and state.nodes[self.ticket.index].epoch == self.epoch and Bool(state.nodes[self.ticket.index].deadline)

    def fire(self) -> Bool:
        """Fire the pending deadline of this epoch; false when it is stale."""
        var guard = _lock_metadata(self.cell)
        ref state = guard.cell[].slot.value()
        if not state.valid(self.ticket) or state.nodes[self.ticket.index].epoch != self.epoch or not state.nodes[self.ticket.index].deadline:
            return False
        state.clear_timer(self.ticket.index, fired=True)
        state.nodes[self.ticket.index].own_ready = True
        var notify = state.wake(self.ticket.index)
        var scheduler = state.scheduler.copy()
        _ = guard^
        _notify(notify, scheduler)
        return True


@fieldwise_init
struct _Subscriber(Copyable):
    var generation: UInt64
    var target: Optional[_Waker]


@fieldwise_init
struct _HookSubscriber(Copyable):
    """A hook fired under the signal's lock (see `_subscribe_hook`); kept apart from wakers."""
    var generation: UInt64
    var hook: Optional[_WakeHook]


struct _EventState(Movable):
    var revision: UInt64
    var entries: List[_Subscriber]
    var free: List[Int]
    var active: Int
    # Hook subscriptions, in their own list so the wakers' path is unchanged.
    var hooks: List[_HookSubscriber]
    var hooks_free: List[Int]

    def __init__(out self):
        self.revision = 0
        self.entries = List[_Subscriber]()
        self.free = List[Int]()
        self.active = 0
        self.hooks = List[_HookSubscriber]()
        self.hooks_free = List[Int]()


struct Signal(Copyable):
    """Shared readiness notification, safe from any thread.

    Copies share one revision. `notify` and `revision` take the signal's lock,
    so writes a thread makes before `notify` are visible to a thread whose later
    `revision` read observes the change. Read the revision before inspecting
    state, and touch plain shared state only after observing a change.
    `Wait.changed(signal, revision)` compares revisions when it registers, so a
    notify landing between the read and the wait is not lost. A notify after a
    waiter's registration retired, or after its root finished, wakes nothing.
    A signal never moves payloads: external adapters keep ownership of their
    data, and its thread safety, until they report a terminal outcome.
    """
    var _cell: ArcPointer[_Cell[_EventState]]

    def __init__(out self):
        """Create a fresh shared readiness source."""
        self._cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_EventState())))

    def revision(self) -> UInt64:
        """Read a revision before inspecting the associated readiness state.

        Returns:
            A generation token to pass to Wait.changed if still pending.
        """
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        return state.revision

    def notify(self):
        """Advance the shared revision and notify every live subscription."""
        var targets = List[_Waker]()
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        state.revision = _next_generation(state.revision)
        for entry in state.entries:
            if entry.target:
                targets.append(entry.target.value().copy())
        # Under the lock, so a hook never fires after its subscription is
        # dropped; a hook takes no lock, so this cannot deadlock.
        for entry in state.hooks:
            if entry.hook:
                entry.hook.value().fire()
        _ = guard^
        for target in targets:
            _ = target.wake()

    def _subscribe(self, revision: UInt64, target: _Waker) -> _Subscription:
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        var index = len(state.entries)
        var generation = UInt64(1)
        if len(state.free):
            index = state.free.pop()
            generation = _next_generation(state.entries[index].generation)
            state.entries[index] = _Subscriber(generation, Optional(target.copy()))
        else:
            state.entries.append(_Subscriber(generation, Optional(target.copy())))
        state.active += 1
        var changed = revision != state.revision
        _ = guard^
        if changed:
            _ = target.wake()
        return _Subscription(self.copy(), index, generation)

    def _subscribe_hook(self, revision: UInt64, hook: _WakeHook) -> _Subscription:
        """Fire a hook on every later notify until the subscription is dropped.

        The hook fires under this signal's lock, at once when the revision has
        already moved past `revision`, so after the returned subscription is
        dropped (which takes the same lock) it never fires again. The caller
        keeps the hook's target alive until then. The subscription's index is
        negative: `-1 - i` names hook entry `i`.
        """
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        var index = len(state.hooks)
        var generation = UInt64(1)
        if len(state.hooks_free):
            index = state.hooks_free.pop()
            generation = _next_generation(state.hooks[index].generation)
            state.hooks[index] = _HookSubscriber(generation, Optional(hook))
        else:
            state.hooks.append(_HookSubscriber(generation, Optional(hook)))
        if revision != state.revision:
            hook.fire()
        _ = guard^
        return _Subscription(self.copy(), -1 - index, generation)


# Canonical compatibility name for existing internal consumers.
comptime _Event = Signal


@fieldwise_init
struct _Subscription(Movable):
    var event: _Event
    var index: Int
    var generation: UInt64

    def __deinit__(deinit self):
        var guard = _lock_metadata(self.event._cell)
        ref state = guard.cell[].slot.value()
        if self.index < 0:
            var hook = -1 - self.index
            if state.hooks[hook].generation != self.generation or not state.hooks[hook].hook:
                abort("wake subscription retired twice")
            state.hooks[hook].hook = None
            state.hooks_free.append(hook)
            return
        if state.entries[self.index].generation != self.generation or not state.entries[self.index].target:
            abort("wake subscription retired twice")
        state.entries[self.index].target = None
        state.free.append(self.index)
        state.active -= 1
