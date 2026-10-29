"""Resumable finalization and lexical cancellation masks over shared scopes."""
from std.builtin.rebind import downcast, rebind_var
from std.os import abort
from fp.callables import OnceUnary, UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables._binding import _OwnedUnary
from fp._internal.errors import _ErrorCompatible
from fp.effects import IOContext, ExitCase, Outcome
from fp.effects.finalization import Poll as _SyncPoll
from fp.effects.outcomes import _capture, _discard, _failure_as
from fp.effects._io_core import _settle
from .kernel import Machine, Step, Wait, _Slot, _tick
from .scopes import ScopedMachine, CleanupMachine, Scope, _ProgramUse
from .children import _tick_scoped
from .composition import Pure, pure


struct _ExitCleanup[F: ScopedMachine, only_cancel: Bool = False](CleanupMachine):
    comptime Input = NoneType
    comptime Error = Self.F.Error
    var slot: _Slot[Self.F, Self.F.Value, Self.Error]
    def __init__(out self, var finalizer: Self.F):
        comptime assert Self.F.Input == ExitCase[Self.Error], "finalizer must borrow the exact ExitCase"
        self.slot = _Slot[Self.F, Self.F.Value, Self.Error](finalizer^)
    def poll[o: ImmOrigin](mut self, ref[o] unit: NoneType, exit: ExitCase[Self.Error], context: IOContext[Self.Error]) -> Step[NoneType, Self.Error]:
        comptime assert Self.F.Input == ExitCase[Self.Error]
        if Self.only_cancel and not exit.is_canceled():
            var ignored: NoneType = None
            var completed = pure[Self.Error](ignored)
            return completed.poll(context)
        _ = _tick_scoped(self.slot, rebind[Self.F.Input](exit), context)
        if not self.slot.done():
            return .pending(self.slot.waiting())
        var outcome = self.slot.take_outcome()
        if not outcome:
            return .ready(None)
        return .ready(Optional(_discard(outcome.take())))


comptime Guarantee[P: Machine, F: ScopedMachine, only_cancel: Bool = False] = Scope[Pure[NoneType, P.Error], _ProgramUse[P, NoneType], _ExitCleanup[F, only_cancel]]


def guarantee_case[P: Machine, F: ScopedMachine](var program: P, var finalizer: F) -> Guarantee[P, F]:
    comptime assert P.Error == F.Error, "finalizer requires the same exact error type"
    var unit: NoneType = None
    return Guarantee[P, F](pure[P.Error](unit), _ProgramUse[P, NoneType](program^), _ExitCleanup(finalizer^))


def _guarantee[P: Machine, Q: Machine, only_cancel: Bool](var program: P, var finalizer: Q) -> Guarantee[P, _ProgramUse[Q, ExitCase[P.Error]], only_cancel]:
    comptime assert P.Error == Q.Error, "finalizer requires the same exact error type"
    var unit: NoneType = None
    comptime Finalizer = _ProgramUse[Q, ExitCase[P.Error]]
    return Guarantee[P, Finalizer, only_cancel](pure[P.Error](unit), _ProgramUse[P, NoneType](program^), _ExitCleanup[Finalizer, only_cancel](Finalizer(finalizer^)))


def guarantee[P: Machine, Q: Machine](var program: P, var finalizer: Q) -> Guarantee[P, _ProgramUse[Q, ExitCase[P.Error]]]:
    return _guarantee[P, Q, False](program^, finalizer^)


def on_cancel[P: Machine, Q: Machine](var program: P, var finalizer: Q) -> Guarantee[P, _ProgramUse[Q, ExitCase[P.Error]], True]:
    return _guarantee[P, Q, True](program^, finalizer^)


@fieldwise_init
struct Poll[E: Movable & Deinitable](Copyable):
    var source: _SyncPoll[Self.E]
    comptime Applied[P: Machine] = _Polled[P, Self.E]
    def apply[P: Machine](self, var program: P) -> _Polled[P, Self.E]:
        comptime assert P.Error == Self.E, "poll requires the same exact error type"
        return _Polled[P, Self.E](_Slot[P, P.Value, P.Error](program^), self.copy())


@fieldwise_init
struct _Polled[P: Machine, E: Movable & Deinitable](Machine):
    comptime Value = Self.P.Value
    comptime Error = Self.E
    var slot: _Slot[Self.P, Self.P.Value, Self.P.Error]
    var handle: Poll[Self.E]
    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.Value, Self.E]:
        comptime assert Self.P.Error == Self.E
        var restored = self.handle.source._restore(context)
        _ = _tick(self.slot, rebind[IOContext[Self.P.Error]](restored))
        if self.slot.done():
            return rebind_var[Step[Self.Value, Self.E]](self.slot.take_step())
        return .pending(self.slot.waiting())


struct Masked[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](Machine):
    comptime Program = downcast[Self.F.Out, Machine]
    comptime Value = Self.Program.Value
    comptime Error = Self.E
    var factory: Optional[Self.F]
    var masked: Optional[IOContext[Self.E]]
    var active: Optional[_Slot[Self.Program, Self.Value, Self.E]]
    var completed: Bool
    def __init__(out self, var factory: Self.F):
        comptime assert Self.F.Arg == Poll[Self.E] and _OnceUnaryAvailable[Self.F], "masked factory must consume the exact Poll"
        comptime assert Self.Program.Error == Self.E and _ErrorCompatible[Self.E, Self.F.Error], "masked factory requires exact compatible errors"
        self.factory = Optional(factory^)
        self.masked = None
        self.active = None
        self.completed = False
    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.Value, Self.E]:
        comptime assert Self.F.Arg == Poll[Self.E]
        comptime assert Self.Program.Error == Self.E and _ErrorCompatible[Self.E, Self.F.Error]
        if self.completed:
            abort("masked region polled after completion")
        if not self.masked:
            if context.canceled():
                self.completed = True
                return .ready(None)
            self.masked = Optional(context._mask())
            var poll = Poll(_SyncPoll(context.copy(), self.masked.value()._region.value().copy()))
            var built = _capture[Self.E](_OwnedUnary(self.factory.take(), rebind_var[Self.F.Arg](poll^)))
            if built.is_err():
                self.completed = True
                return .ready(_settle(_failure_as[Self.Value](Optional(built^)), context))
            self.active = Optional(_Slot[Self.Program, Self.Value, Self.E](rebind_var[Self.Program](built^._take_ok())))
            return .pending(Wait())
        _ = _tick(rebind[_Slot[Self.Program, Self.Program.Value, Self.Program.Error]](self.active.value()), rebind[IOContext[Self.Program.Error]](self.masked.value()))
        if self.active.value().done():
            self.completed = True
            return Step(Optional(self.active.value().take_outcome()), Wait(), True)
        return .pending(self.active.value().waiting())


def uncancelable_with[F: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](var factory: F) -> Masked[F, E]:
    return Masked[F, E](factory^)


@fieldwise_init
struct _ConstantMask[P: Machine](OnceUnary):
    var program: Self.P
    comptime Arg = Poll[Self.P.Error]
    comptime Out = Self.P
    def call_once(deinit self, var poll: Self.Arg) -> Self.P:
        return self.program^


def uncancelable[P: Machine](var program: P) -> Masked[_ConstantMask[P], P.Error]:
    return uncancelable_with[P.Error](_ConstantMask(program^))
