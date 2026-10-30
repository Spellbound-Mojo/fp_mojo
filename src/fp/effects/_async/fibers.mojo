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
from std.memory import ArcPointer
from fp.data import Result, Ok
from fp._internal.erased import _Erased
from fp._internal.waking import _Event as Signal
from fp.effects import CancellationToken, IOContext, Outcome, EffectFailure
from fp.effects.outcomes import _failure_as
from .kernel import Machine, Step, Wait, _tick
from .children import _Child
from .erased import _ErasedMachine


struct _FiberRecord[E: Movable & Deinitable](Movable):
    """What a fiber's handle shares with its host, typed only by E."""
    var token: CancellationToken
    var signal: Signal
    # The settled outcome; a success holds the handle's T, erased.
    var outcome: Optional[Outcome[_Erased, Self.E]]
    var done: Bool

    def __init__(out self):
        self.token = CancellationToken()
        self.signal = Signal()
        self.outcome = None
        self.done = False


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
            entry.child.attach(context)
            _ = _tick(entry.child.slot, entry.child.context)
            var done = entry.child.slot.done()
            self.admit(context)
            if done:
                self.finished(selected)

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


@fieldwise_init
struct _Join[T: Movable & Deinitable, E: Movable & Deinitable](Machine):
    comptime Value = Outcome[Self.T, Self.E]
    comptime Error = Self.E
    var record: ArcPointer[_FiberRecord[Self.E]]

    def poll(mut self, context: IOContext[Self.E]) -> Step[Outcome[Self.T, Self.E], Self.E]:
        ref record = self.record[]
        var revision = record.signal.revision()
        if record.done:
            var outcome = record.outcome.take()
            var typed: Outcome[Self.T, Self.E]
            if outcome and outcome.value().is_ok():
                # The child's run loop boxed a value its IO type fixed as T.
                typed = Optional(Result[Self.T, EffectFailure[Self.E]](Ok(outcome.take()._take_ok().take[Self.T]())))
            else:
                typed = _failure_as[Self.T](outcome^)
            return Step[Self.Value, Self.E].ready(Optional(Result[Self.Value, EffectFailure[Self.E]](Ok(typed^))))
        if context.canceled():
            return Step[Self.Value, Self.E].ready(None)
        return Step[Self.Value, Self.E].pending(Wait.changed(record.signal, revision))


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
