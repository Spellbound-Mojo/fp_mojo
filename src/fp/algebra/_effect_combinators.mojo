"""Policies and continuations for effectful reductions and conditional bind."""
from fp.callables.protocols import BinaryContract, ThunkContract, UnaryContract
from fp.callables._identity import Identity
from fp._internal.errors import _CommonError, _ErrorCompatible
from .protocols import Monad, _LiveAccumulator, Monoid, _start_as, _flat_map_as, _fold_as
from ._sequencing import _choose_effect, _IfEffect
from ._accumulation import _Combine, _FoldMappedStep, _SearchStep, _BoolLive, _PredicateStep
from .contracts import _EffectFold
from .protocols import _AllLive




def _fold_effect[G: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
                 K: _LiveAccumulator, E: Movable & Deinitable](var function: F, var initial: K.Acc, var source: V
) raises E -> _EffectFold[G, V, F, K].Out:
    return _fold_as[E, G, V, Identity[F.Second], F, K](Identity[F.Second](), function^, initial^, source^)


def _if_effect[G: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](
    var condition: V, var on_true: L, var on_false: R
) raises E -> G.Bound[V, _IfEffect[G, L, R]]:
    comptime assert G.Element[V] == Bool, "if_effect: Bool condition required"
    comptime assert _ErrorCompatible[E, G.BindError[V, _IfEffect[G, L, R]]]
    return _flat_map_as[E, G](_IfEffect[G, L, R](on_true^, on_false^), condition^)


def _fold_map_effect[G: Monad, M: Monoid, V: Movable & Deinitable,
                     F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](
    var function: F, var source: V
) raises E -> _EffectFold[G, V, _FoldMappedStep[G, M, F], _AllLive[M.Value]].Out:
    comptime assert _ErrorCompatible[E, M.Error]
    # Identity construction precedes source binding, even for a deferred G.
    # Mapping and combination follow the selected family's existing timing.
    var initial = _start_as[E, _Combine[M]]()
    return _fold_effect[G, V, _FoldMappedStep[G, M, F], _AllLive[M.Value], E](
        _FoldMappedStep[G, M, F](function^), initial^, source^)
