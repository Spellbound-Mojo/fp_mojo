"""Structured child pairs: one owner, independent tokens, and complete draining."""
from std.os import abort
from fp.effects import CancellationToken, IOContext
from fp.effects.outcomes import _zip_outcomes
from .kernel import Machine, Step, Wait, _Slot, _tick
from .scopes import ScopedMachine
from .time import Instant


struct _Child[P: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    var slot: _Slot[Self.P, Self.T, Self.E]
    var context: IOContext[Self.E]

    def __init__(out self, var program: Self.P, tag: Int = 0):
        self.slot = _Slot[Self.P, Self.T, Self.E](program^, tag)
        self.context = IOContext[Self.E](CancellationToken(), False)

    def attach(mut self, parent: IOContext[Self.E]):
        self.context._inherit(parent)
        self.slot.prepare(self.context)

    def cancel(self):
        if not self.slot.done():
            self.context.request_cancel()

    def ready(self, now: Instant) -> Bool:
        return self.slot.ready(now, self.context)

    def include(self, mut wait: Wait):
        if not self.slot.done() and not self.slot._scheduled:
            wait._include(self.slot._wait, self.context)


struct _Drain(Copyable):
    var requested: Bool

    def __init__(out self):
        self.requested = False

    def observe[E: Movable & Deinitable](mut self, context: IOContext[E], failed: Bool) -> Bool:
        if not self.requested and (context.canceled() or failed):
            self.requested = True
            return True
        return False

    def waiting(self) -> Wait:
        var wait = Wait.never()
        # A delivered parent request must not spin while masked children park.
        wait._interruptible = not self.requested
        return wait^


struct _Pair[P: Movable & Deinitable, Q: Movable & Deinitable,
    T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](Movable):
    var left: _Child[Self.P, Self.T, Self.E]
    var right: _Child[Self.Q, Self.U, Self.E]
    var turn: Int
    var drain: _Drain
    var completed: Bool

    def __init__(out self, var left: Self.P, var right: Self.Q):
        self.left = _Child[Self.P, Self.T, Self.E](left^)
        self.right = _Child[Self.Q, Self.U, Self.E](right^, 1)
        self.turn = 0
        self.drain = _Drain()
        self.completed = False

    def stop_if_needed(mut self, context: IOContext[Self.E]):
        self.request_stop(context, self.left.slot.failed() or self.right.slot.failed())

    def request_stop(mut self, context: IOContext[Self.E], trigger: Bool):
        if self.drain.observe(context, trigger):
            self.left.cancel()
            self.right.cancel()

    def select(mut self, context: IOContext[Self.E], stop_on_failure: Bool = True) -> Int:
        if self.completed:
            abort("child group polled after completion")
        if stop_on_failure:
            self.stop_if_needed(context)
        else:
            self.request_stop(context, False)
        self.left.attach(context)
        self.right.attach(context)
        if context._runtime and context._parent:
            var next = context._runtime.value().next_child(context._parent.value())
            return next.value() if next else -1
        var now = context._clock.now()
        var left_ready = self.left.ready(now)
        var right_ready = self.right.ready(now)
        if left_ready and (self.turn == 0 or not right_ready):
            self.turn = 1
            return 0
        if right_ready:
            self.turn = 0
            return 1
        return -1

    def after_poll(mut self, context: IOContext[Self.E]) -> Step[Tuple[Self.T, Self.U], Self.E]:
        self.stop_if_needed(context)
        if self.left.slot.done() and self.right.slot.done():
            self.completed = True
            return .ready(_zip_outcomes(self.left.slot.take_outcome(), self.right.slot.take_outcome()))
        return .pending(self.waiting())

    def waiting(self) -> Wait:
        var wait = self.drain.waiting()
        self.left.include(wait)
        self.right.include(wait)
        return wait^


struct Both[P: Machine, Q: Machine](Machine):
    comptime Value = Tuple[Self.P.Value, Self.Q.Value]
    comptime Error = Self.P.Error
    var _pair: _Pair[Self.P, Self.Q, Self.P.Value, Self.Q.Value, Self.P.Error]

    def __init__(out self, var left: Self.P, var right: Self.Q):
        comptime assert Self.P.Error == Self.Q.Error, "children require the same exact error type"
        self._pair = _Pair[Self.P, Self.Q, Self.P.Value, Self.Q.Value, Self.P.Error](left^, right^)

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.P.Error == Self.Q.Error
        match self._pair.select(context):
            case 0:
                _ = _tick(self._pair.left.slot, self._pair.left.context)
            case 1:
                _ = _tick(rebind[_Slot[Self.Q, Self.Q.Value, Self.Q.Error]](self._pair.right.slot), rebind[IOContext[Self.Q.Error]](self._pair.right.context))
            case _:
                pass
        return self._pair.after_poll(context)


def both[P: Machine, Q: Machine](var left: P, var right: Q) -> Both[P, Q]:
    return Both(left^, right^)


def _tick_scoped[P: ScopedMachine, o: ImmOrigin](mut slot: _Slot[P, P.Value, P.Error],
    ref[o] value: P.Input, context: IOContext[P.Error]
) -> Bool:
    # Only this native invocation boundary differs from _tick; slot policy is shared.
    slot.prepare(context)
    if not slot.ready(context._clock.now(), context):
        return False
    if slot.enter(context):
        var step = slot._program.value()[].poll(value, slot.poll_context(context))
        slot.accept(step^, context)
    return True


struct ScopedBoth[P: ScopedMachine, Q: ScopedMachine](ScopedMachine):
    comptime Input = Self.P.Input
    comptime Value = Tuple[Self.P.Value, Self.Q.Value]
    comptime Error = Self.P.Error
    var _pair: _Pair[Self.P, Self.Q, Self.P.Value, Self.Q.Value, Self.P.Error]

    def __init__(out self, var left: Self.P, var right: Self.Q):
        comptime assert Self.P.Error == Self.Q.Error and Self.P.Input == Self.Q.Input
        self._pair = _Pair[Self.P, Self.Q, Self.P.Value, Self.Q.Value, Self.P.Error](left^, right^)

    def poll[o: ImmOrigin](mut self, ref[o] value: Self.Input, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.P.Error == Self.Q.Error and Self.P.Input == Self.Q.Input
        match self._pair.select(context):
            case 0:
                _ = _tick_scoped(self._pair.left.slot, value, self._pair.left.context)
            case 1:
                _ = _tick_scoped(rebind[_Slot[Self.Q, Self.Q.Value, Self.Q.Error]](self._pair.right.slot), rebind[Self.Q.Input](value), rebind[IOContext[Self.Q.Error]](self._pair.right.context))
            case _:
                pass
        return self._pair.after_poll(context)


def scoped_both[P: ScopedMachine, Q: ScopedMachine](var left: P, var right: Q) -> ScopedBoth[P, Q]:
    return ScopedBoth(left^, right^)
