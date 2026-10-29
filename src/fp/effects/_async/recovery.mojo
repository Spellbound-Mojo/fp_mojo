"""Recovery through the canonical bind continuation and selected family policy."""
from fp.effects.outcomes import EffectFailure
from fp.callables.protocols import OnceThunk, UnaryContract
from fp.callables.native import NativeUnary, _Unary, _RaisingUnary
from fp.algebra._outcomes import _Materialize
from .kernel import Machine as _Machine
from .family import Async, _Recipe, _Handled
from .io import delay, EvalIO
from fp.effects._io_core import DelayContract


@fieldwise_init
struct _Raise[E: Movable & Deinitable, T: Movable & Deinitable](OnceThunk):
    var error: Self.E
    comptime Out = Self.T
    comptime Error = Self.E
    def call_once(deinit self) raises Self.Error -> Self.Out:
        raise self.error^


def raise_error[E: Movable & Deinitable, T: Movable & Deinitable](var error: E) -> _Recipe[EvalIO[DelayContract[_Raise[E, T], E].Out]]:
    return _Recipe(delay[E](_Raise[E, T](error^)))


def handle_error_with[P: _Machine, H: UnaryContract & Movable & Deinitable](var program: P, var handler: H) -> Async[P.Error].Handled[P, H] where Async[P.Error]._Handles[P, H]:
    return Async[P.Error].or_else(handler^, program^)


def handle_error_with[P: _Machine, R: _Machine, //, H: _Unary[EffectFailure[P.Error], R]](var program: P, var handler: H
) -> Async[P.Error].Handled[P, NativeUnary[EffectFailure[P.Error], R, Never, H, False]] where Async[P.Error]._Handles[P, NativeUnary[EffectFailure[P.Error], R, Never, H, False]]:
    return handle_error_with(program^, NativeUnary[EffectFailure[P.Error], R, Never, H, False](handler^))


def handle_error_with[P: _Machine, R: _Machine, X: Movable & Deinitable, //, H: _RaisingUnary[EffectFailure[P.Error], R, X]](var program: P, var handler: H
) -> Async[P.Error].Handled[P, NativeUnary[EffectFailure[P.Error], R, X, H, True]] where Async[P.Error]._Handles[P, NativeUnary[EffectFailure[P.Error], R, X, H, True]]:
    return handle_error_with(program^, NativeUnary[EffectFailure[P.Error], R, X, H, True](handler^))


def attempt[P: _Machine](var program: P) -> _Materialize[Async[P.Error], P].Out where _Materialize[Async[P.Error], P].MapCompatible and _Materialize[Async[P.Error], P].HandleCompatible:
    return _Materialize[Async[P.Error], P].apply[Never](program^)
