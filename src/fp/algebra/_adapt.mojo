"""Exact native-error adaptation for calls to algebra family primitives."""
from fp.algebra.protocols import ApplicativeError, _map_as, _flat_map_as, _map2_lazy_as
from fp.callables.protocols import UnaryContract
from fp._internal.errors import _ErrorCompatible, _propagate_error


def _or_else_as[E: Movable & Deinitable, M: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](
    var handler: H, var source: V
) raises E -> M.Handled[V, H] where M._Handles[V, H] and _ErrorCompatible[E, M.HandleError[V, H]]:
    try:
        return M.or_else(handler^, source^)
    except error:
        _propagate_error[E](error^)


def _fail_as[E: Movable & Deinitable, M: ApplicativeError, A: Movable & Deinitable](var error: M.Failure
) raises E -> M.Failed[A] where _ErrorCompatible[E, M.FailError[A]]:
    try:
        return M.fail[A](error^)
    except raised:
        _propagate_error[E](raised^)
