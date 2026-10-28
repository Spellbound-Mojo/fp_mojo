"""Compatibility bridge for synchronous native resource scopes."""
from std.builtin.rebind import rebind_var
from fp.callables.protocols import BorrowCallContract
from fp.callables._receiver import _OnceBorrowAvailable
from fp.callables.native import _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp._internal.errors import _ErrorCompatible
from .protocols import ReaderAction
from .resources import Resource, _OpenScope
from .outcomes import Outcome
from ._io_core import IO, IOContext, _settle


@fieldwise_init
struct _IOResource[O: _OpenScope, F: BorrowCallContract & Movable & Deinitable](ReaderAction):
    var scope: Resource[Self.O]
    var function: Self.F
    comptime E = Self.O.Release.Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.F.Result
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert Self.F.Payload == Self.O.Release.Value and _ErrorCompatible[Self.E, Self.F.Failure] and _OnceBorrowAvailable[Self.F]
        if env.canceled():
            return None
        return _settle(Optional(self.scope^.use(self.function^)), env)


def use_resource[O: _OpenScope, F: BorrowCallContract & Movable & Deinitable](var scope: Resource[O], var function: F
) -> _IOResource[O, F] where F.Payload == O.Release.Value and _ErrorCompatible[O.Release.Error, F.Failure] and _OnceBorrowAvailable[F]:
    """Defer an entire synchronous native resource scope into its IO error family.

    Cancellation is observed before entry and after release. Native acquisition,
    use and release are synchronous and cannot be interrupted midway. This keeps
    release registered until it runs and preserves all native scope failures.

    Parameters:
        O: The concrete resource recipe.
        F: A borrowing native-use callback expressed through library contracts.

    Args:
        scope: The unopened scope, consumed into the IO recipe.
        function: The native use callback, consumed without executing now.

    Returns:
        An IO program yielding F.Result, with the scope's exact error family.
    """
    return _IOResource(scope^, function^)


def use_resource[O: _OpenScope, P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](var scope: Resource[O], var function: F
) -> _IOResource[O, _NativeBorrow[P, V, Never, F, False]] where P == O.Release.Value:
    """Adapt a native borrowing use callback into a deferred resource scope."""
    return use_resource(scope^, _NativeBorrow[P, V, Never, F, False](function^))


def use_resource[O: _OpenScope, P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](var scope: Resource[O], var function: F
) -> _IOResource[O, _NativeBorrow[P, V, X, F, True]] where P == O.Release.Value and _ErrorCompatible[O.Release.Error, X]:
    """Adapt a native use callback with the scope's exact error type."""
    return use_resource(scope^, _NativeBorrow[P, V, X, F, True](function^))
