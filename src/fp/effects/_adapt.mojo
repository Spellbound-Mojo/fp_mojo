"""Error-adapting calls: a combinator raising one common native error calls a
child computation or a base operation whose own error is Never or that type.

Evidence for each where clause comes from the caller's assertion. One try block
may only contain calls with one error type, so each adapted call is separate.
"""
from fp.algebra.protocols import Functor, Applicative, Monad
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract
from fp._internal.errors import _ErrorCompatible, _propagate_error
from .protocols import ReaderAction, StateAction


def _reader_run_as[E: Movable & Deinitable, V: ReaderAction, o: ImmOrigin](var action: V, ref[o] env: V.Env
) raises E -> V.Out[o] where _ErrorCompatible[E, V.Error[o]]:
    try:
        return action^.run(env)
    except error:
        _propagate_error[E](error^)


def _state_run_as[E: Movable & Deinitable, V: StateAction](var action: V, var state: V.State
) raises E -> V.Out where _ErrorCompatible[E, V.Error]:
    try:
        return action^.run(state^)
    except error:
        _propagate_error[E](error^)


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
