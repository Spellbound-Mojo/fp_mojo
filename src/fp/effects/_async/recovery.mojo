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
    """Construct a deferred failure containing one exact domain error.

    Parameters:
        E: The selected domain error type, consumed without conversion.
        T: The success type of the failed recipe.

    Args:
        error: The owned domain error, retained until execution or discard.

    Returns:
        An unopened recipe producing the canonical full failure.
    """
    return _Recipe(delay[E](_Raise[E, T](error^)))


def handle_error_with[P: _Machine, H: UnaryContract & Movable & Deinitable](var program: P, var handler: H) -> Async[P.Error].Handled[P, H] where Async[P.Error]._Handles[P, H]:
    """Recover a noncanceled failure through the selected Async family.

    Parameters:
        P: The source machine and its exact value/error origins.
        H: The once-admitted handler consuming EffectFailure[P.Error].

    Args:
        program: The unopened source, consumed once.
        handler: Builds a replacement with the same value and domain error.

    Returns:
        A deferred recipe. Cancellation-only and mixed canceled failures bypass
        the handler. Handler failure replaces the consumed original failure.
    """
    return Async[P.Error].or_else(handler^, program^)


def handle_error_with[P: _Machine, R: _Machine, //, H: _Unary[EffectFailure[P.Error], R]](var program: P, var handler: H
) -> Async[P.Error].Handled[P, NativeUnary[EffectFailure[P.Error], R, Never, H, False]] where Async[P.Error]._Handles[P, NativeUnary[EffectFailure[P.Error], R, Never, H, False]]:
    """Adapt a native recovery handler through the canonical callable boundary.
    """
    return handle_error_with(program^, NativeUnary[EffectFailure[P.Error], R, Never, H, False](handler^))


def handle_error_with[P: _Machine, R: _Machine, X: Movable & Deinitable, //, H: _RaisingUnary[EffectFailure[P.Error], R, X]](var program: P, var handler: H
) -> Async[P.Error].Handled[P, NativeUnary[EffectFailure[P.Error], R, X, H, True]] where Async[P.Error]._Handles[P, NativeUnary[EffectFailure[P.Error], R, X, H, True]]:
    """Adapt a native recovery handler through the canonical callable boundary.
    """
    return handle_error_with(program^, NativeUnary[EffectFailure[P.Error], R, X, H, True](handler^))


def attempt[P: _Machine](var program: P) -> _Materialize[Async[P.Error], P].Out where _Materialize[Async[P.Error], P].MapCompatible and _Materialize[Async[P.Error], P].HandleCompatible:
    """Materialize success or ordinary failure without recovering cancellation.

    Parameters:
        P: The concrete source machine, retaining native origins.

    Args:
        program: The unopened source, consumed once.

    Returns:
        A recipe yielding Result[P.Value, EffectFailure[P.Error]]. Cancellation
        and mixed canceled failures remain terminal in the outer outcome.
    """
    return _Materialize[Async[P.Error], P].apply[Never](program^)
