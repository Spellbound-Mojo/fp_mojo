"""Error-adapting calls: a combinator raising one common native error calls a
child computation or a base operation whose own error is Never or that type.

Evidence for each where clause comes from the caller's assertion. One try block
may only contain calls with one error type, so each adapted call is separate.
"""
from fp._internal.errors import _ErrorCompatible, _propagate_error
from fp.algebra._adapt import _map_as, _flat_map_as, _map2_lazy_as
from fp.algebra.protocols import _Lifting
from .protocols import Local, ReaderAction, StateAction, _CarrierOp
from fp.callables.protocols import BorrowCallContract


def _lift_as[E: Movable & Deinitable, I: _Lifting, V: Movable & Deinitable](var value: V
) raises E -> I.Lifted[V] where _ErrorCompatible[E, I.LiftError[V]]:
    try:
        return I.lift(value^)
    except error:
        _propagate_error[E](error^)


def _local_as[E: Movable & Deinitable, C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V
) raises E -> C.Localized[V, F] where C.LocalCompatible[V] and F.Payload == C.Environment and F.Result == C.Environment and _ErrorCompatible[E, C.LocalError[V, F]]:
    try:
        return C.local(f^, value^)
    except error:
        _propagate_error[E](error^)


def _reader_run_as[E: Movable & Deinitable, V: ReaderAction, o: ImmOrigin](var action: V, ref[o] env: V.Env
) raises E -> V.Out[o] where _ErrorCompatible[E, V.Error[o]] and V._RunCompatible[o]:
    try:
        return action^.run(env)
    except error:
        _propagate_error[E](error^)


def _state_run_as[E: Movable & Deinitable, V: StateAction](var action: V, var state: V.State
) raises E -> V.Out where _ErrorCompatible[E, V.Error] and V._RunCompatible:
    try:
        return action^.run(state^)
    except error:
        _propagate_error[E](error^)


def _op_as[E: Movable & Deinitable, H: _CarrierOp, V: Movable & Deinitable](var op: H, var value: V
) raises E -> H.Applied[V] where H.Compatible[V] and _ErrorCompatible[E, H.Error[V]]:
    try:
        return op^.apply(value^)
    except error:
        _propagate_error[E](error^)
