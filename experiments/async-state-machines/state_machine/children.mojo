"""Structured child pairs: one owner, independent tokens, and complete draining."""
from std.time import monotonic
from std.os import abort
from fp.effects import CancellationToken, IOContext
from fp.effects.outcomes import _zip_outcomes
from .kernel import Machine, Step, Wait, _Slot, _tick
from .scopes import ScopedMachine


struct _Pair[P: Movable & Deinitable, Q: Movable & Deinitable,
    T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](Movable):
    var left: _Slot[Self.P, Self.T, Self.E]
    var right: _Slot[Self.Q, Self.U, Self.E]
    var left_context: IOContext[Self.E]
    var right_context: IOContext[Self.E]
    var turn: Int
    var draining: Bool
    var completed: Bool

    def __init__(out self, var left: Self.P, var right: Self.Q):
        self.left = _Slot[Self.P, Self.T, Self.E](left^)
        self.right = _Slot[Self.Q, Self.U, Self.E](right^)
        self.left_context = IOContext[Self.E](CancellationToken(), False)
        self.right_context = IOContext[Self.E](CancellationToken(), False)
        self.turn = 0
        self.draining = False
        self.completed = False

    def stop_if_needed(mut self, context: IOContext[Self.E]):
        if not self.draining and (context.canceled() or self.left.failed() or self.right.failed()):
            self.draining = True
            if not self.left.done():
                self.left_context.request_cancel()
            if not self.right.done():
                self.right_context.request_cancel()

    def select(mut self, context: IOContext[Self.E]) -> Int:
        if self.completed:
            abort("child group polled after completion")
        self.stop_if_needed(context)
        var now = monotonic()
        var left_ready = self.left.ready(now, self.left_context)
        var right_ready = self.right.ready(now, self.right_context)
        if left_ready and (self.turn == 0 or not right_ready):
            self.turn = 1
            return 0
        if right_ready:
            self.turn = 0
            return 1
        return -1

    def after_poll(mut self, context: IOContext[Self.E]) -> Step[Tuple[Self.T, Self.U], Self.E]:
        self.stop_if_needed(context)
        if self.left.done() and self.right.done():
            self.completed = True
            return .ready(_zip_outcomes(self.left.take_outcome(), self.right.take_outcome()))
        var wait = Wait.never()
        # A delivered parent request must not spin while masked children park.
        wait.interruptible = not self.draining
        if not self.left.done():
            wait.include(self.left._wait, self.left_context)
        if not self.right.done():
            wait.include(self.right._wait, self.right_context)
        return .pending(wait^)


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
                _ = _tick(self._pair.left, self._pair.left_context)
            case 1:
                _ = _tick(rebind[_Slot[Self.Q, Self.Q.Value, Self.Q.Error]](self._pair.right), rebind[IOContext[Self.Q.Error]](self._pair.right_context))
            case _:
                pass
        return self._pair.after_poll(context)


def both[P: Machine, Q: Machine](var left: P, var right: Q) -> Both[P, Q]:
    return Both(left^, right^)


def _tick_scoped[P: ScopedMachine, o: ImmOrigin](mut slot: _Slot[P, P.Value, P.Error],
    ref[o] value: P.Input, context: IOContext[P.Error]
) -> Bool:
    # Only this native invocation boundary differs from _tick; slot policy is shared.
    if not slot.ready(monotonic(), context):
        return False
    if slot.enter(context):
        var step = slot._program.value()[].poll(value, context)
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
                _ = _tick_scoped(self._pair.left, value, self._pair.left_context)
            case 1:
                _ = _tick_scoped(rebind[_Slot[Self.Q, Self.Q.Value, Self.Q.Error]](self._pair.right), rebind[Self.Q.Input](value), rebind[IOContext[Self.Q.Error]](self._pair.right_context))
            case _:
                pass
        return self._pair.after_poll(context)


def scoped_both[P: ScopedMachine, Q: ScopedMachine](var left: P, var right: Q) -> ScopedBoth[P, Q]:
    return ScopedBoth(left^, right^)
