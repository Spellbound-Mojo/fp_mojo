"""Exact native-error adaptation for calls to algebra family primitives."""
from fp.algebra.protocols import Functor, Applicative, Monad, ApplicativeError
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from fp._internal.errors import _ErrorCompatible, _propagate_error


def _map_as[E: Movable & Deinitable, M: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var value: V
) raises E -> M.Mapped[V, F] where _ErrorCompatible[E, M.MapError[V, F]]:
    try:
        return M.map(f^, value^)
    except error:
        _propagate_error[E](error^)


def _flat_map_as[E: Movable & Deinitable, M: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var value: V
) raises E -> M.Bound[V, F] where _ErrorCompatible[E, M.BindError[V, F]]:
    try:
        return M.flat_map(f^, value^)
    except error:
        _propagate_error[E](error^)


def _map2_lazy_as[E: Movable & Deinitable, M: Applicative, V: Movable & Deinitable,
                  F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
    var f: F, var left: V, var right: R
) raises E -> M.Combined[V, F, R] where _ErrorCompatible[E, M.CombineError[V, F, R]]:
    try:
        return M.map2_lazy(f^, left^, right^)
    except error:
        _propagate_error[E](error^)


def _or_else_as[E: Movable & Deinitable, M: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](
    var handler: H, var source: V
) raises E -> M.Handled[V, H] where M._Handles[V, H] and _ErrorCompatible[E, M.HandleError[V, H]]:
    try:
        return M.or_else(handler^, source^)
    except error:
        _propagate_error[E](error^)
