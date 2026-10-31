"""Generation-checked wake registries and the scheduling state of tasks.

A `_Runtime` is the wake registry of one task: a tree of generation-checked
nodes behind one lock, one per execution slot of that task, so wakes for
different tasks never contend. Ready siblings form intrusive FIFO lists, and a
wake propagates readiness up to the registry's root node. When the root's list
becomes non-empty, the registry's wake hook schedules the task that owns it.

A task is a `_TaskHeader`: an atomic scheduling state (idle, scheduled,
running, notified while running, done) and its owned, erased body, which this
module never runs. The `_Scheduler`, shared by every registry under one root,
holds the ready queue, the timer heap, the host notifier, and the diagnostic
table of live fibers. Wakes may arrive from any thread; everything else is
confined to the thread that drives the root (the current-thread profile).
"""
from std.atomic import Atomic, Ordering
from std.collections import BinaryHeap, Deque
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic, sleep
from .cells import _Cell, _lock_metadata
from .erased import _Erased
from .time import Instant


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

comptime _TaskRun = def(mut _Erased) thin -> Bool
"""Run a task body once; true when the task has finished."""


def _no_run(mut body: _Erased) -> Bool:
    abort("the root task is run by its driver")


struct _TaskHeader(Movable):
    """A task: its atomic scheduling state and its owned, erased body.

    A queue entry is the right to run the task: the state is scheduled exactly
    while one entry exists, and only the executor that popped it touches the
    body, while the state is running or notified. Between runs the body stays
    here, so moving the entry between workers moves that right with it.
    """
    var state: Atomic[UInt8]
    # The executor turn in which the task last ran; touched only by the executor.
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

    def begin_run(mut self):
        # The queue lock that handed over the entry already ordered the body's
        # writes before this point (acquire); relaxed suffices for the marker.
        self.state.store[ordering=Ordering.RELAXED](_RUNNING)

    def finish(mut self):
        """Mark the task done and destroy its body now, not when the last reference goes."""
        self.state.store[ordering=Ordering.RELEASE](_DONE)
        self.body = _Erased()
        self.registry = None

    def runnable(self) -> Bool:
        """Whether the task is scheduled, running, or notified, for diagnostics."""
        var state = self.state.load[ordering=Ordering.ACQUIRE]()
        return state == _SCHEDULED or state == _RUNNING or state == _NOTIFIED


def _schedule(task: ArcPointer[_TaskHeader], scheduler: ArcPointer[_Scheduler]) -> Bool:
    """The wake hook: schedule an idle task, or mark a running one notified.

    Called with the task's registry locked, as every wake and every park take
    that lock. Returns whether the host must be notified.
    """
    # Acquire pairs with the release of the park that made the task idle.
    var state = task[].state.load[ordering=Ordering.ACQUIRE]()
    while True:
        if state == _IDLE:
            # Acquire-release: the push publishes the task to the executor.
            if task[].state.compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.ACQUIRE_RELEASE](state, _SCHEDULED):
                return scheduler[].push(task.copy())
        elif state == _RUNNING:
            if task[].state.compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.ACQUIRE_RELEASE](state, _NOTIFIED):
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
struct _FiberEntry(Movable):
    var owner: Int
    var draining: Bool
    var task: ArcPointer[_TaskHeader]


@fieldwise_init
struct _FiberView(Copyable):
    """One live fiber's metadata for a driver snapshot."""
    var index: Int
    var owner: Int
    # 0 runnable, 1 suspended, 2 draining.
    var status: Int


struct _FiberTable(Movable):
    """Live fibers' metadata, without payloads; slots are reused."""
    var entries: List[Optional[_FiberEntry]]
    var free: List[Int]

    def __init__(out self):
        self.entries = List[Optional[_FiberEntry]]()
        self.free = List[Int]()


struct _Scheduler(Movable):
    """What every wake registry of one root shares.

    The ready queue and the notifier state are safe from any thread. The timer
    heap and the fiber table are touched only by the thread driving the root;
    their locks are never held while another lock is taken, except that the
    heap's maintenance locks registries, which never take the heap's lock.
    """
    var ready: ArcPointer[_Cell[_ReadyQueue]]
    var timers: ArcPointer[_Cell[_TimerState]]
    # Deadlines currently armed in every registry, to bound the heap's tombstones.
    var live_timers: Atomic[Int]
    var fibers: ArcPointer[_Cell[_FiberTable]]
    # Whether the root is being polled; set and read sequentially consistently
    # with the queue's contents (see push and the driver's poll).
    var polling: Atomic[UInt8]
    var closed: Atomic[UInt8]
    var in_flight: Atomic[Int]
    var notifier: Optional[_Notifier]

    def __init__(out self):
        self.ready = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReadyQueue())))
        self.timers = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_TimerState())))
        self.live_timers = Atomic(0)
        self.fibers = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_FiberTable())))
        self.polling = Atomic(UInt8(0))
        self.closed = Atomic(UInt8(0))
        self.in_flight = Atomic(0)
        self.notifier = None

    def push(mut self, var task: ArcPointer[_TaskHeader]) -> Bool:
        """Queue a scheduled task; true when the host must be notified.

        The host is told only when the queue was empty and no poll is running:
        a poll in progress reports the task itself. The sequentially consistent
        load of `polling` after the push pairs with the driver clearing it
        before it reads the queue, so one of the two always sees the task.
        """
        var guard = _lock_metadata(self.ready)
        ref queue = guard.cell[].slot.value()
        var was_empty = len(queue) == 0
        queue.push(task^)
        _ = guard^
        return was_empty and self.polling.load[ordering=Ordering.SEQUENTIAL]() == 0

    def pop(mut self) -> Optional[ArcPointer[_TaskHeader]]:
        var guard = _lock_metadata(self.ready)
        return guard.cell[].slot.value().pop()

    def queued(self) -> Int:
        var guard = _lock_metadata(self.ready)
        return len(guard.cell[].slot.value())

    def set_polling(mut self, polling: Bool):
        self.polling.store[ordering=Ordering.SEQUENTIAL](UInt8(1) if polling else UInt8(0))

    def notify_host(mut self):
        """Call the notifier unless the driver finished; `close` waits for this call.

        Entering increments `in_flight` before reading `closed`, and closing
        sets `closed` before reading `in_flight`, both sequentially consistent:
        either the call sees the driver closed, or close sees the call and waits.
        """
        if not self.notifier:
            return
        _ = self.in_flight.fetch_add[ordering=Ordering.SEQUENTIAL](1)
        if self.closed.load[ordering=Ordering.SEQUENTIAL]() == 0:
            ref notifier = self.notifier.value()
            var call = notifier.call
            call(notifier.target)
        # Release: the call happens before close observes the count.
        _ = self.in_flight.fetch_sub[ordering=Ordering.RELEASE](1)

    def close(mut self):
        """Stop notifying the host and wait for a call in progress."""
        self.closed.store[ordering=Ordering.SEQUENTIAL](1)
        while self.in_flight.load[ordering=Ordering.SEQUENTIAL]() != 0:
            sleep(0.0)

    def shutdown(mut self):
        """Release what a finished root shares, on the thread that drives it.

        A waker retained by another thread may hold the last reference to a
        registry, and through it to this scheduler, after the root finishes.
        Stale heap entries also refer back to registries, a cycle. Emptying the
        heap, the queue, the fiber table and the notifier here breaks the cycle
        and leaves only plain metadata for another thread to destroy; the host's
        notifier is destroyed here, after `close`.
        """
        self.close()
        var timers = _lock_metadata(self.timers)
        timers.cell[].slot.value().heap = BinaryHeap[_Timer]()
        _ = timers^
        var ready = _lock_metadata(self.ready)
        ready.cell[].slot.value() = _ReadyQueue()
        _ = ready^
        var fibers = _lock_metadata(self.fibers)
        fibers.cell[].slot.value() = _FiberTable()
        _ = fibers^
        self.notifier = None

    def push_timer(mut self, deadline: Instant, var target: _Waker):
        var guard = _lock_metadata(self.timers)
        ref timers = guard.cell[].slot.value()
        timers.sequence = _next_generation(timers.sequence)
        timers.heap.push(_Timer(deadline.copy(), timers.sequence, target^))
        if len(timers.heap) > 2 * self.live_timers.load[ordering=Ordering.RELAXED]() + 32:
            var retained = BinaryHeap[_Timer]()
            while len(timers.heap):
                var timer = timers.heap.pop()
                if timer.target.timer_live():
                    retained.push(timer^)
            timers.heap = retained^

    def fire_due(mut self, now: Instant) -> Bool:
        """Fire the earliest live due timer; false when none is due."""
        while True:
            var guard = _lock_metadata(self.timers)
            ref timers = guard.cell[].slot.value()
            if not len(timers.heap) or timers.heap.peek().deadline > now:
                return False
            var timer = timers.heap.pop()
            _ = guard^
            if timer.target.fire():
                return True

    def next_deadline(mut self) -> Optional[Instant]:
        """The earliest live deadline, discarding stale entries above it."""
        while True:
            var guard = _lock_metadata(self.timers)
            ref timers = guard.cell[].slot.value()
            if not len(timers.heap):
                return None
            if timers.heap.peek().target.timer_live():
                return Optional(timers.heap.peek().deadline.copy())
            _ = timers.heap.pop()

    def retained_timers(self) -> Int:
        var guard = _lock_metadata(self.timers)
        return len(guard.cell[].slot.value().heap)

    def register_fiber(mut self, owner: Int, task: ArcPointer[_TaskHeader]) -> Int:
        """Record a live fiber; returns its slot, from 1."""
        var guard = _lock_metadata(self.fibers)
        ref table = guard.cell[].slot.value()
        var index = len(table.entries)
        if len(table.free):
            index = table.free.pop()
            table.entries[index] = Optional(_FiberEntry(owner, False, task.copy()))
        else:
            table.entries.append(Optional(_FiberEntry(owner, False, task.copy())))
        return index + 1

    def set_draining(mut self, fiber: Int):
        var guard = _lock_metadata(self.fibers)
        guard.cell[].slot.value().entries[fiber - 1].value().draining = True

    def release_fiber(mut self, fiber: Int):
        var guard = _lock_metadata(self.fibers)
        ref table = guard.cell[].slot.value()
        table.entries[fiber - 1] = None
        table.free.append(fiber - 1)

    def fiber_slots(self) -> Int:
        var guard = _lock_metadata(self.fibers)
        return len(guard.cell[].slot.value().entries)

    def snapshot(self) -> List[_FiberView]:
        var views = List[_FiberView]()
        var guard = _lock_metadata(self.fibers)
        ref table = guard.cell[].slot.value()
        for index in range(len(table.entries)):
            if table.entries[index]:
                ref entry = table.entries[index].value()
                var status = 1
                if entry.draining:
                    status = 2
                elif entry.task[].runnable():
                    status = 0
                views.append(_FiberView(index + 1, entry.owner, status))
        return views^


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

    def clear_timer(mut self, index: Int):
        if self.nodes[index].deadline:
            self.nodes[index].deadline = None
            self.live_timers -= 1
            _ = self.scheduler[].live_timers.fetch_sub[ordering=Ordering.RELAXED](1)


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
            task[].state.store[ordering=Ordering.RELEASE](_SCHEDULED)
            notify = state.scheduler[].push(task.copy())
        else:
            task[].state.store[ordering=Ordering.RELEASE](_IDLE)
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
        if deadline:
            state.nodes[index].deadline = deadline.copy()
            state.live_timers += 1
            _ = state.scheduler[].live_timers.fetch_add[ordering=Ordering.RELAXED](1)
        if runnable:
            state.nodes[index].own_ready = True
        var notify = state.reconcile(index)
        var epoch = state.nodes[index].epoch
        var scheduler = state.scheduler.copy()
        _ = guard^
        if deadline:
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
        state.clear_timer(self.ticket.index)
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


struct _EventState(Movable):
    var revision: UInt64
    var entries: List[_Subscriber]
    var free: List[Int]
    var active: Int

    def __init__(out self):
        self.revision = 0
        self.entries = List[_Subscriber]()
        self.free = List[Int]()
        self.active = 0


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
        if state.entries[self.index].generation != self.generation or not state.entries[self.index].target:
            abort("wake subscription retired twice")
        state.entries[self.index].target = None
        state.free.append(self.index)
        state.active -= 1
