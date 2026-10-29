"""Typed single-completion registration with owned, suspending withdrawal."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.builtin.rebind import downcast, rebind_var
from std.os import abort
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables._binding import _OwnedUnary
from fp._internal.errors import _ErrorCompatible
from fp.effects import IOContext, CancellationToken, Outcome
from fp.effects.coordination import _Cell, _lock, _try_lock
from fp.effects.outcomes import _discard, _capture, _finish, _failure_as, _ExitState
from fp.effects._io_core import _settle
from .kernel import Machine, Step, Wait, Signal, _Slot, _tick


# Both native no-result signatures and explicit unit values are admissible.
# Registration discards its unit through the canonical result owner.
comptime _CallbackUnit[T: Movable & Deinitable] = T == NoneType or T == type_of(None)


@fieldwise_init
struct _CompletionState[T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    var closed: Bool
    var result: Optional[Outcome[Self.T, Self.E]]

    def take(mut self) -> Optional[Outcome[Self.T, Self.E]]:
        if self.result:
            return Optional(self.result.take())
        return None


trait _CompletionType:
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable


struct Completion[T: Movable & Deinitable, E: Movable & Deinitable](Copyable, _CompletionType):
    """Copies share one terminal decision; the cell survives late callbacks.

    Parameters:
        T: The exact owned completion value, including external origins.
        E: The exact domain error of the registration and withdrawal scope.
    """
    comptime Value = Self.T
    comptime Error = Self.E
    var _cell: ArcPointer[_Cell[_CompletionState[Self.T, Self.E]]]
    var _signal: Signal
    var _mask: IOContext[Self.E]

    def __init__(out self):
        self._cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_CompletionState[Self.T, Self.E](False, None))))
        self._signal = Signal()
        self._mask = IOContext[Self.E](CancellationToken(), True)

    def complete(self, var outcome: Outcome[Self.T, Self.E]) -> Bool:
        """Offer an owned terminal outcome once through the cooperative host boundary.

        Args:
            outcome: The success, complete ordered failure, or cancellation-only value.

        Returns:
            True if accepted. False after completion or withdrawal has closed admission;
            rejected payloads are destroyed outside the metadata lock."""
        var locked = _lock(self._cell, self._mask)
        var guard = locked.take()
        var accepted = not guard.cell[].slot.value().closed
        if accepted:
            guard.cell[].slot.value().closed = True
            guard.cell[].slot.value().result = Optional(outcome^)
        # Never destroy rejected payloads or invoke producers while locked.
        _ = guard^
        self._signal.notify()
        return accepted

    def _select(self, cancel: Bool) -> Optional[Outcome[Self.T, Self.E]]:
        var locked = _try_lock(self._cell)
        if not locked:
            return None
        var guard = locked.take()
        if not guard.cell[].slot.value().closed and cancel:
            guard.cell[].slot.value().closed = True
            guard.cell[].slot.value().result = Optional(Outcome[Self.T, Self.E]())
        var selected = guard.cell[].slot.value().take()
        _ = guard^
        return selected^

    def _registration_failed(self, var failed: Outcome[NoneType, Self.E]) -> Outcome[Self.T, Self.E]:
        var locked = _lock(self._cell, self._mask)
        var guard = locked.take()
        guard.cell[].slot.value().closed = True
        var selected = guard.cell[].slot.value().take()
        _ = guard^
        self._signal.notify()
        if selected:
            return _finish(selected.take(), failed^)
        return _failure_as[Self.T](failed^)


struct Callback[F: UnaryContract & Movable & Deinitable, C: Machine](Machine):
    comptime Contract = downcast[Self.F.Arg, _CompletionType]
    comptime Value = Self.Contract.Value
    comptime Error = Self.Contract.Error
    var register: Optional[Self.F]
    var completion: Completion[Self.Value, Self.Error]
    var cleanup: _Slot[Self.C, Self.C.Value, Self.C.Error]
    var completed: Optional[_ExitState[Self.Value, Self.Error]]
    var masked: Optional[IOContext[Self.Error]]
    var phase: Int

    def __init__(out self, var register: Self.F, var cleanup: Self.C):
        comptime assert Self.F.Arg == Completion[Self.Value, Self.Error] and _CallbackUnit[Self.F.Out]
        comptime assert _OnceUnaryAvailable[Self.F] and _ErrorCompatible[Self.Error, Self.F.Error]
        comptime assert _CallbackUnit[Self.C.Value] and Self.C.Error == Self.Error
        self.register = Optional(register^)
        self.completion = Completion[Self.Value, Self.Error]()
        self.cleanup = _Slot[Self.C, Self.C.Value, Self.C.Error](cleanup^)
        self.completed = None
        self.masked = None
        self.phase = 0

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.F.Arg == Completion[Self.Value, Self.Error] and _CallbackUnit[Self.F.Out]
        comptime assert _OnceUnaryAvailable[Self.F] and _ErrorCompatible[Self.Error, Self.F.Error]
        comptime assert _CallbackUnit[Self.C.Value] and Self.C.Error == Self.Error
        match self.phase:
            case 0:
                if context.canceled():
                    self.phase = 3
                    return .ready(None)
                var registered = _capture[Self.Error](_OwnedUnary(self.register.take(), rebind_var[Self.F.Arg](self.completion.copy())))
                if registered.is_err():
                    self.begin_cleanup(self.completion._registration_failed(Optional(_discard(registered^))), context)
                else:
                    self.phase = 1
                return .pending(Wait())
            case 1:
                var revision = self.completion._signal.revision()
                var selected = self.completion._select(context.canceled())
                if selected:
                    self.begin_cleanup(selected.take(), context)
                    return .pending(Wait())
                var wait = Wait.changed(self.completion._signal, revision)
                wait._interruptible = not context._masked
                return .pending(wait^)
            case 2:
                _ = _tick(self.cleanup, rebind[IOContext[Self.C.Error]](self.masked.value()))
                if not self.cleanup.done():
                    var wait = self.cleanup.waiting()
                    wait._interruptible = False
                    return .pending(wait^)
                var cleanup = rebind_var[Outcome[Self.C.Value, Self.Error]](self.cleanup.take_outcome())
                var outcome = _finish(self.completed.take().outcome(), cleanup^)
                self.phase = 3
                return .ready(_settle(outcome^, context))
            case _:
                abort("callback polled after completion")

    def begin_cleanup(mut self, var outcome: Outcome[Self.Value, Self.Error], context: IOContext[Self.Error]):
        self.completed = Optional(_ExitState(_settle(outcome^, context)))
        self.masked = Optional(context._mask())
        self.phase = 2


def callback[F: UnaryContract & Movable & Deinitable, C: Machine](var register: F, var cleanup: C) -> Callback[F, C]:
    return Callback(register^, cleanup^)
