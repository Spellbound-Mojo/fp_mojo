"""Error-adapting calls: a combinator raising one common native error calls a
child computation or a base operation whose own error is Never or that type.

Evidence for each where clause comes from the caller's assertion. One try block
may only contain calls with one error type, so each adapted call is separate.
"""
from fp._internal.errors import _ErrorCompatible, _propagate_error
from fp.algebra._adapt import _map_as, _flat_map_as, _map2_lazy_as
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
