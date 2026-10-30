"""Generation-checked wake metadata; never stores task code or payloads."""
from std.atomic import Atomic
from std.collections import BinaryHeap
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from .cells import _Cell, _lock_metadata
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
    var ticket: _Ticket
    var epoch: UInt64

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


struct _ReadyState(Movable):
    var nodes: List[_Node]
    var free: List[Int]
    var timers: BinaryHeap[_Timer]
    var sequence: UInt64
    var active: Int
    var live_timers: Int

    def __init__(out self):
        self.nodes = List[_Node]()
        self.nodes.append(_Node(1, -1, -1))
        self.free = List[Int]()
        self.timers = BinaryHeap[_Timer]()
        self.sequence = 0
        self.active = 0
        self.live_timers = 0

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

    def wake(mut self, var index: Int):
        while index > 0:
            var parent = self.nodes[index].parent
            if not self.nodes[index].queued:
                var previous = self.nodes[parent].last
                self.nodes[index].previous = previous
                self.nodes[index].next = -1
                if previous < 0:
                    self.nodes[parent].first = index
                else:
                    self.nodes[previous].next = index
                self.nodes[parent].last = index
                self.nodes[index].queued = True
            index = parent

    def reconcile(mut self, var index: Int):
        while index > 0:
            if self.nodes[index].own_ready or self.nodes[index].first >= 0:
                self.wake(index)
                return
            self.unlink(index)
            index = self.nodes[index].parent

    def clear_timer(mut self, index: Int):
        if self.nodes[index].deadline:
            self.nodes[index].deadline = None
            self.live_timers -= 1

    def timer_valid(self, timer: _Timer) -> Bool:
        return self.valid(timer.ticket) and self.nodes[timer.ticket.index].epoch == timer.epoch and Bool(self.nodes[timer.ticket.index].deadline)

    def trim(mut self):
        while len(self.timers) and not self.timer_valid(self.timers.peek()):
            _ = self.timers.pop()

    def compact(mut self):
        if len(self.timers) <= 2 * self.live_timers + 32:
            return
        var retained = BinaryHeap[_Timer]()
        while len(self.timers):
            var timer = self.timers.pop()
            if self.timer_valid(timer):
                retained.push(timer^)
        self.timers = retained^


struct _Runtime(Copyable):
    var _cell: ArcPointer[_Cell[_ReadyState]]

    def __init__(out self):
        self._cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReadyState())))

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
        state.wake(index)
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
        state.reconcile(parent)
        state.compact()

    def begin(self, ticket: _Ticket):
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        if not state.valid(ticket):
            abort("poll of a retired registration")
        state.unlink(ticket.index)
        state.nodes[ticket.index].own_ready = False
        state.clear_timer(ticket.index)
        state.nodes[ticket.index].epoch = _next_generation(state.nodes[ticket.index].epoch)
        state.compact()

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
            state.sequence = _next_generation(state.sequence)
            state.timers.push(_Timer(deadline.value().copy(), state.sequence,
                                                       ticket.copy(), state.nodes[index].epoch))
        if runnable:
            state.nodes[index].own_ready = True
        state.reconcile(index)

    def fire_due(self, now: Instant) -> Bool:
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        state.trim()
        if not len(state.timers) or state.timers.peek().deadline > now:
            return False
        var timer = state.timers.pop()
        state.clear_timer(timer.ticket.index)
        state.nodes[timer.ticket.index].own_ready = True
        state.wake(timer.ticket.index)
        return True

    def next_deadline(self) -> Optional[Instant]:
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        state.trim()
        if not len(state.timers):
            return None
        return Optional(state.timers.peek().deadline.copy())

    def waker(self, ticket: _Ticket) -> _Waker:
        var guard = _lock_metadata(self._cell)
        ref state = guard.cell[].slot.value()
        return _Waker(self.copy(), ticket.copy(), state.nodes[ticket.index].epoch)


@fieldwise_init
struct _Waker(Copyable):
    var runtime: _Runtime
    var ticket: _Ticket
    var epoch: UInt64

    def wake(self) -> Bool:
        var guard = _lock_metadata(self.runtime._cell)
        ref state = guard.cell[].slot.value()
        if not state.valid(self.ticket) or state.nodes[self.ticket.index].epoch != self.epoch:
            return False
        state.nodes[self.ticket.index].own_ready = True
        state.wake(self.ticket.index)
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
    """Shared readiness notification for cooperative host-thread integration.

    Copies share a revision. A signal does not establish cross-thread callback
    safety, device completion, or memory visibility for external work. External
    adapters retain those obligations until they report a terminal outcome.
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
