"""Policies and continuations for effectful reductions and conditional bind."""
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import BinaryContract, Binary, ThunkContract, OnceUnary, MutableUnary, BorrowCallable, UnaryContract
from fp.callables.invoke import invoke_borrowed, RepeatableThunk
from fp.callables._receiver import _ThunkView, _thunk_once_as
from fp.callables._identity import Identity
from fp._internal.errors import _CommonError, _ErrorCompatible
from .protocols import Monad, _LiveAccumulator, Monoid, _start_as, _flat_map_as, _fold_as
from ._accumulation import _Combine, _FoldMappedStep, _SearchStep
from .contracts import _EffectFold
from .protocols import _AllLive




struct _BoolLive[all_values: Bool](_LiveAccumulator):
    comptime Acc = Bool
    @staticmethod
    def live(ref acc: Bool) -> Bool: return acc == Self.all_values


@fieldwise_init
struct _PredicateStep[C: BorrowCallable](Binary):
    var predicate: Self.C
    comptime First = Bool
    comptime Second = downcast[Self.C.Payload, Movable & Deinitable]
    comptime Out = Self.C.Result
    comptime Error = Self.C.Failure
    def call(self, var first: Bool, var second: Self.Second) raises Self.Error -> Self.Out:
        comptime assert Self.Second == Self.C.Payload
        return invoke_borrowed[Self.Error](second, self.predicate)




def _fold_effect[G: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
                 K: _LiveAccumulator, E: Movable & Deinitable](var function: F, var initial: K.Acc, var source: V
) raises E -> _EffectFold[G, V, F, K].Out:
    return _fold_as[E, G, V, Identity[F.Second], F, K](Identity[F.Second](), function^, initial^, source^)


def _choose_effect[G: Monad, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
    condition: Bool, var on_true: L, var on_false: R
) raises _CommonError[L.Error, R.Error] -> G._Joined[L.Out, R.Out]:
    comptime E = _CommonError[L.Error, R.Error]
    comptime assert _ErrorCompatible[E, L.Error] and _ErrorCompatible[E, R.Error], "if_effect: incompatible native errors"
    comptime assert G.Element[L.Out] == G.Element[R.Out], "if_effect: branches must have the same payload type"
    if condition:
        return G._join_left[L.Out, R.Out](_thunk_once_as[E](on_true^))
    return G._join_right[L.Out, R.Out](_thunk_once_as[E](on_false^))


@fieldwise_init
struct _IfEffect[G: Monad, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableThunk[L] and RepeatableThunk[R]
):
    var on_true: Self.L
    var on_false: Self.R
    comptime Arg = Bool
    comptime Out = Self.G._Joined[Self.L.Out, Self.R.Out]
    comptime Error = _CommonError[Self.L.Error, Self.R.Error]
    def call_once(deinit self, var arg: Bool) raises Self.Error -> Self.Out:
        return _choose_effect[Self.G](arg, self.on_true^, self.on_false^)
    def call_mut(mut self, var arg: Bool) raises Self.Error -> Self.Out:
        var left = _ThunkView(Pointer(to=self.on_true))
        var right = _ThunkView(Pointer(to=self.on_false))
        return _choose_effect[Self.G](arg, left^, right^)


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
