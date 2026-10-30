"""Fiber records and host tables: the scheduling half of `IO.start`.

`io.start()` reserves a slot in its host's inbox, queues the child there, and
returns a `Fiber` handle. The entered IO that ran the first start hosts every
fiber started beneath it, including fibers started by fibers, in one table of
execution slots registered under the host's own wake node, so nested fibers
cost no native stack. An IO inside a lifted leaf hosts its own fibers. The IO
surface, `Fiber` and `start`, lives in `engine.mojo` and builds on this module.

A handle and its child share a record typed only by E: the child's token, a
completion signal, and the settled outcome, whose success holds T erased. When a
fiber's own program is terminal, it cancels its live children and completes only
after they do, so fibers never outlive their owner. Slots of completed fibers
are reused.
"""
from std.builtin.rebind import downcast
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp._internal.erased import _Erased
from fp._internal.waking import _Event as Signal
from fp.effects import CancellationToken, IOContext, Outcome, EffectFailure
from fp.effects.outcomes import _failure_as
from fp.effects._io_core import _Reporter
from .kernel import Machine, Step, Wait, _tick, _report_to_stderr
from .time import Instant
from .children import _Child
from .erased import _ErasedMachine


struct FiberStatus(Copyable, Equatable, Writable):
    """Where a live fiber stands in a driver snapshot."""
    var _code: Int

    @staticmethod
    def runnable() -> Self:
        """Ready to run on a coming poll, including a fiber not yet entered.

        Returns:
            The runnable status.
        """
        return Self(_code=0)

    @staticmethod
    def suspended() -> Self:
        """Parked until a signal, timer, or cancellation wakes it.

        Returns:
            The suspended status.
        """
        return Self(_code=1)

    @staticmethod
    def draining() -> Self:
        """Its program has finished; it waits for its own children to finish.

        Returns:
            The draining status.
        """
        return Self(_code=2)

    def __init__(out self, *, _code: Int):
        self._code = _code

    def __eq__(self, other: Self) -> Bool:
        return self._code == other._code

    def __ne__(self, other: Self) -> Bool:
        return self._code != other._code

    def write_to(self, mut writer: Some[Writer]):
        """Write the status name: runnable, suspended, or draining.

        Args:
            writer: The destination.
        """
        if self._code == 0:
            writer.write("runnable")
        elif self._code == 1:
            writer.write("suspended")
        else:
            writer.write("draining")


@fieldwise_init
struct FiberInfo(Copyable, Writable):
    """One live fiber in a driver snapshot, without payloads or completed work.

    There is no public fiber identity, as in Cats Effect: the index names a
    slot of the root IO's fiber table and is reused once the fiber completes.
    """
    var index: Int
    """The fiber's slot, from 1; 0 is the root program itself."""
    var owner: Int
    """The slot of the fiber that started it, or 0 for the root program."""
    var status: FiberStatus
    """Runnable, suspended, or draining its children."""


trait _FiberHost:
    """A machine that can list the fibers it hosts, for driver snapshots."""
    def _fiber_snapshot(self, now: Instant) -> List[FiberInfo]:
        ...


struct _FiberRecord[E: Movable & Deinitable](Movable):
    """What a fiber's handle shares with its host, typed only by E."""
    var token: CancellationToken
    var signal: Signal
    # The settled outcome; a success holds the handle's T, erased.
    var outcome: Optional[Outcome[_Erased, Self.E]]
    var done: Bool
    # Set once the last claim to the outcome is gone; it can no longer be joined.
    var released: Bool
    var report: Bool
    var reporter: _Reporter

    def __init__(out self):
        self.token = CancellationToken()
        self.signal = Signal()
        self.outcome = None
        self.done = False
        self.released = False
        self.report = True
        self.reporter = _report_to_stderr

    def identity(self) -> Int:
        return Int(self.signal._cell.ptr())

    def settle(mut self):
        """Dispose of an outcome nobody can join: report a failure, drop a success."""
        if not self.done or not self.released or not self.outcome:
            return
        var outcome = self.outcome.take()
        if not outcome or outcome.value().is_ok() or not self.report:
            return
        self.reporter(_describe(outcome.take()._take_err()))


def _describe[E: Movable & Deinitable](var failure: EffectFailure[E]) -> String:
    """One line for an unhandled failure: its errors, or their type and count."""
    var line = String("unhandled fiber failure: ")
    var canceled = failure.canceled
    var errors = failure^.into_errors().into_list()
    comptime if conforms_to(E, Writable):
        for index in range(len(errors)):
            if index:
                line.write("; ")
            line.write(rebind[downcast[E, Writable]](errors[index]))
    else:
        line.write(len(errors), " error(s) of type ", reflect[E].name())
    if canceled:
        line.write(" (canceled)")
    return line


struct _Claim[E: Movable & Deinitable](Movable):
    """The single right to a fiber's outcome, held by its handle and then by its join.

    Dropping the claim without taking the outcome releases the record: a
    failure is reported, now or when the child completes, and a success is
    destroyed once.
    """
    var record: ArcPointer[_FiberRecord[Self.E]]

    def __init__(out self, var record: ArcPointer[_FiberRecord[Self.E]]):
        self.record = record^

    def __deinit__(deinit self):
        self.record[].released = True
        self.record[].settle()

    def keep(deinit self) -> ArcPointer[_FiberRecord[Self.E]]:
        """Consume the claim after taking the outcome; nothing is left to release."""
        return self.record^


@fieldwise_init
struct _Spawn[E: Movable & Deinitable](Movable):
    """A started child: its run loop as an erased leaf, and its reserved slot."""
    var program: _ErasedMachine[_Erased, Self.E]
    var record: ArcPointer[_FiberRecord[Self.E]]
    var owner: Int
    var index: Int

    def enter(deinit self, context: IOContext[Self.E]) -> _FiberEntry[Self.E]:
        """Give the child its slot, registered under its host with tag index + 1."""
        var child = _Child[_ErasedMachine[_Erased, Self.E], _Erased, Self.E](self.program^, self.index + 1)
        child.context = IOContext[Self.E](self.record[].token.copy(), False)
        child.attach(context)
        child.context._fiber = self.record[].identity()
        if context._budget:
            self.record[].report = context._budget.value()[].report
            self.record[].reporter = context._budget.value()[].reporter
        return _FiberEntry[Self.E](child^, self.record^, self.owner, 0, None)


struct _Inbox[E: Movable & Deinitable](Movable):
    """Fibers started since their host last admitted, and the host's free slots.

    Shared by the host and every run loop it hosts. A start reserves its slot
    here, so the child's run loop knows its fiber id before it is admitted.
    """
    var pending: List[_Spawn[Self.E]]
    var free: List[Int]
    var size: Int

    def __init__(out self):
        self.pending = List[_Spawn[Self.E]]()
        self.free = List[Int]()
        self.size = 0

    def reserve(mut self) -> Int:
        if len(self.free):
            return self.free.pop()
        self.size += 1
        return self.size - 1


@fieldwise_init
struct _FiberEntry[E: Movable & Deinitable](Movable):
    var child: _Child[_ErasedMachine[_Erased, Self.E], _Erased, Self.E]
    var record: ArcPointer[_FiberRecord[Self.E]]
    # Fiber ids: 0 is the host's own program, and entry i is fiber i + 1.
    var owner: Int
    var children: Int
    # A terminal program waiting for its children to finish.
    var held: Optional[Outcome[_Erased, Self.E]]


struct _Fibers[E: Movable & Deinitable](Movable):
    """The fibers an entered IO hosts, in one table of reusable slots."""
    var inbox: ArcPointer[_Inbox[Self.E]]
    var entries: List[Optional[_FiberEntry[Self.E]]]
    var main_children: Int
    var main_wait: Wait
    var main_outcome: Optional[Outcome[_Erased, Self.E]]
    var main_protected: Bool
    var fibers_first: Bool
    var turn: Int

    def __init__(out self, inbox: ArcPointer[_Inbox[Self.E]]):
        self.inbox = inbox.copy()
        self.entries = List[Optional[_FiberEntry[Self.E]]]()
        self.main_children = 0
        self.main_wait = Wait()
        self.main_outcome = None
        self.main_protected = False
        self.fibers_first = False
        self.turn = 0

    def main_done(self) -> Bool:
        return Bool(self.main_outcome)

    def admit(mut self, context: IOContext[Self.E]):
        var pending = List[_Spawn[Self.E]]()
        swap(pending, self.inbox[].pending)
        pending.reverse()
        while len(pending):
            var spawn = pending.pop()
            var owner = spawn.owner
            var index = spawn.index
            while len(self.entries) <= index:
                self.entries.append(None)
            self.entries[index] = Optional(spawn^.enter(context))
            self.adopt(owner)

    def adopt(mut self, owner: Int):
        if owner == 0:
            self.main_children += 1
        else:
            self.entries[owner - 1].value().children += 1

    def cancel_children(mut self, owner: Int):
        for index in range(len(self.entries)):
            if self.entries[index] and self.entries[index].value().owner == owner:
                self.entries[index].value().child.cancel()

    def settle_main(mut self, var step: Step[_Erased, Self.E]):
        if not step._completed:
            self.main_wait = step^._waiting()
            return
        self.main_protected = step._protected_success
        self.main_outcome = Optional(step^._outcome())
        self.cancel_children(0)

    def finished(mut self, index: Int):
        """A fiber's program is terminal: drain its children, then complete."""
        ref entry = self.entries[index].value()
        var outcome = entry.child.slot.take_outcome()
        if entry.children:
            entry.held = Optional(outcome^)
            self.cancel_children(index + 1)
            return
        self.complete(index, outcome^)

    def complete(mut self, var index: Int, var outcome: Outcome[_Erased, Self.E]):
        # Completing a fiber may release an owner that was only waiting for it.
        while True:
            var entry = self.entries[index].take()
            entry.record[].outcome = Optional(outcome^)
            entry.record[].done = True
            entry.record[].signal.notify()
            entry.record[].settle()
            self.inbox[].free.append(index)
            var owner = entry.owner
            if owner == 0:
                self.main_children -= 1
                return
            ref parent = self.entries[owner - 1].value()
            parent.children -= 1
            if parent.children or not parent.held:
                return
            outcome = parent.held.take()
            index = owner - 1

    def run_fibers(mut self, context: IOContext[Self.E]):
        """Tick ready fibers while the root budget lasts, once each at most."""
        var scheduled = Bool(context._runtime) and Bool(context._parent)
        var count = len(self.entries)
        for _ in range(count):
            if context._budget and context._budget.value()[].remaining <= 0:
                return
            var selected = -1
            if scheduled:
                # Tag 0 is the host program's own leaf, which runs in its turn.
                var tag = context._runtime.value().next_child(context._parent.value(), 0)
                if not tag:
                    return
                selected = tag.value() - 1
            else:
                var now = context._clock.now()
                for offset in range(count):
                    var index = (self.turn + offset) % count
                    if self.entries[index] and self.entries[index].value().child.ready(now):
                        selected = index
                        self.turn = (index + 1) % count
                        break
                if selected < 0:
                    return
            ref entry = self.entries[selected].value()
            var fiber = entry.child.context._fiber
            entry.child.attach(context)
            entry.child.context._fiber = fiber
            _ = _tick(entry.child.slot, entry.child.context)
            var done = entry.child.slot.done()
            self.admit(context)
            if done:
                self.finished(selected)

    def snapshot(self, now: Instant) -> List[FiberInfo]:
        var fibers = List[FiberInfo]()
        for index in range(len(self.entries)):
            if self.entries[index]:
                ref entry = self.entries[index].value()
                var status = FiberStatus.suspended()
                if entry.held:
                    status = FiberStatus.draining()
                elif entry.child.ready(now):
                    status = FiberStatus.runnable()
                fibers.append(FiberInfo(index + 1, entry.owner, status^))
        return fibers^

    def step(mut self, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        if self.main_done() and not self.main_children:
            return Step[_Erased, Self.E]._make(self.main_outcome.take(), Wait(), self.main_protected)
        var wait: Wait
        if self.main_done():
            # Owned children drain; the host's own request was already forwarded.
            wait = Wait.never()
            wait._interruptible = False
        else:
            wait = self.main_wait.copy()
        for index in range(len(self.entries)):
            if self.entries[index]:
                self.entries[index].value().child.include(wait)
        return Step[_Erased, Self.E].pending(wait^)


struct _Join[E: Movable & Deinitable](Machine):
    """Wait for the child, then hand its outcome and the claim to a delivery."""
    comptime Value = _Delivery[Self.E]
    comptime Error = Self.E
    var claim: Optional[_Claim[Self.E]]

    def __init__(out self, var claim: _Claim[Self.E]):
        self.claim = Optional(claim^)

    def poll(mut self, context: IOContext[Self.E]) -> Step[_Delivery[Self.E], Self.E]:
        ref record = self.claim.value().record[]
        if context._fiber and context._fiber == record.identity():
            abort("a fiber cannot join itself")
        var revision = record.signal.revision()
        # A canceled joiner leaves the outcome; dropping its claim reports it.
        if context.canceled():
            return Step[Self.Value, Self.E].ready(None)
        if record.done:
            var outcome = record.outcome.take()
            var delivery = _Delivery[Self.E](self.claim.take(), Optional(outcome^))
            return Step[Self.Value, Self.E].ready(Optional(Result[Self.Value, EffectFailure[Self.E]](Ok(delivery^))))
        return Step[Self.Value, Self.E].pending(Wait.changed(record.signal, revision))


struct _Delivery[E: Movable & Deinitable](Movable):
    """A joined outcome on its way to the joiner's continuation.

    If cancellation drops it before the join's own frame takes the outcome, the
    outcome returns to the record and the claim's release reports a failure.
    """
    var claim: _Claim[Self.E]
    var outcome: Optional[Outcome[_Erased, Self.E]]

    def __init__(out self, var claim: _Claim[Self.E], var outcome: Optional[Outcome[_Erased, Self.E]]):
        self.claim = claim^
        self.outcome = outcome^

    def __deinit__(deinit self):
        if self.outcome:
            self.claim.record[].outcome = self.outcome^
        # The claim's release settles the record.

    def take(deinit self) -> Outcome[_Erased, Self.E]:
        _ = self.claim^.keep()
        return self.outcome.take()


struct _Unwrap[T: Movable & Deinitable, E: Movable & Deinitable](OnceUnary, Defaultable):
    """The join's own frame: the outcome reaches the joiner, typed as T."""
    comptime Arg = _Delivery[Self.E]
    comptime Out = Outcome[Self.T, Self.E]

    def __init__(out self):
        pass

    def call_once(deinit self, var delivery: _Delivery[Self.E]) -> Outcome[Self.T, Self.E]:
        return _typed[Self.T](delivery^.take())


def _typed[T: Movable & Deinitable, E: Movable & Deinitable](var outcome: Outcome[_Erased, E]) -> Outcome[T, E]:
    """A fiber's settled outcome, its success unboxed as the T its IO type fixed."""
    if outcome and outcome.value().is_ok():
        return Optional(Result[T, EffectFailure[E]](Ok(outcome.take()._take_ok().take[T]())))
    return _failure_as[T](outcome^)


def _unsuccessful[E: Movable & Deinitable](record: _FiberRecord[E]) -> Bool:
    """Whether a finished fiber failed or was canceled."""
    if not record.done or not record.outcome:
        return False
    ref outcome = record.outcome.value()
    return not outcome or outcome.value().is_err()


@fieldwise_init
struct _FirstDone[E: Movable & Deinitable](Machine):
    """Wait for the first of two fibers to finish: true when the left one did.

    The left fiber wins a tie. A caller canceled while waiting cancels both
    fibers and completes canceled only after both finish.
    """
    comptime Value = Bool
    comptime Error = Self.E
    var left: ArcPointer[_FiberRecord[Self.E]]
    var right: ArcPointer[_FiberRecord[Self.E]]
    var stopping: Bool

    def poll(mut self, context: IOContext[Self.E]) -> Step[Bool, Self.E]:
        var left_revision = self.left[].signal.revision()
        var right_revision = self.right[].signal.revision()
        if not self.stopping and context.canceled():
            self.stopping = True
            self.left[].token.cancel()
            self.right[].token.cancel()
        if self.stopping:
            if self.left[].done and self.right[].done:
                return Step[Bool, Self.E].ready(None)
        elif self.left[].done:
            return Step[Bool, Self.E].ready(Optional(Result[Bool, EffectFailure[Self.E]](Ok(True))))
        elif self.right[].done:
            return Step[Bool, Self.E].ready(Optional(Result[Bool, EffectFailure[Self.E]](Ok(False))))
        var either = Wait.changed(self.left[].signal, left_revision)
        var other = Wait.changed(self.right[].signal, right_revision)
        # Once draining, the caller's own request must not wake it again.
        either._interruptible = not self.stopping
        other._interruptible = not self.stopping
        either._include(other, context)
        return Step[Bool, Self.E].pending(either^)


@fieldwise_init
struct _CancelFiber[E: Movable & Deinitable](Machine):
    comptime Value = NoneType
    comptime Error = Self.E
    var record: ArcPointer[_FiberRecord[Self.E]]
    var requested: Bool

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        ref record = self.record[]
        var revision = record.signal.revision()
        if not self.requested:
            record.token.cancel()
            self.requested = True
        if record.done:
            return _unit[Self.E]()
        var wait = Wait.changed(record.signal, revision)
        wait._interruptible = False
        return Step[NoneType, Self.E].pending(wait^)


@fieldwise_init
struct _RequestCancel[E: Movable & Deinitable](Machine):
    comptime Value = NoneType
    comptime Error = Self.E
    var record: ArcPointer[_FiberRecord[Self.E]]

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        self.record[].token.cancel()
        return _unit[Self.E]()


def _unit[E: Movable & Deinitable]() -> Step[NoneType, E]:
    var unit: NoneType = None
    return Step[NoneType, E].ready(Optional(Result[NoneType, EffectFailure[E]](Ok(unit))))
