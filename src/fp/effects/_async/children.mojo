"""Child execution slots: an owned program, its own token, and scoped polling."""
from std.os import abort
from fp.effects import CancellationToken, IOContext
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
