"""Policies and continuations for effectful reductions and conditional bind."""
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import BinaryContract, Binary, ThunkContract, OnceThunk, OnceUnary, MutableUnary, BorrowCallable
from fp.callables.invoke import call_repeated, invoke_borrowed, RepeatableThunk
from fp.callables._receiver import _thunk_once_as
from fp.functions.composition import Identity
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Monad, _LiveAccumulator


struct _AllLive[A: Movable & Deinitable](_LiveAccumulator):
    comptime Acc = Self.A
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool: return True


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


struct _EffectFold[G: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator]:
    comptime Prepare = Identity[Self.F.Second]
    comptime Out = Self.G._Folded[Self.V, Self.Prepare, Self.F, Self.K]
    comptime Error = Self.G._FoldError[Self.V, Self.Prepare, Self.F, Self.K]


def _fold_effect[G: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
                 K: _LiveAccumulator, E: Movable & Deinitable](var function: F, var initial: K.Acc, var source: V
) raises E -> _EffectFold[G, V, F, K].Out:
    try:
        return G._fold[V, Identity[F.Second], F, K](Identity[F.Second](), function^, initial^, source^)
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


@fieldwise_init
struct _ThunkView[F: ThunkContract & Movable & Deinitable, o: MutOrigin](OnceThunk):
    var function: Pointer[Self.F, Self.o]
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert RepeatableThunk[Self.F]
        return call_repeated(self.function[])


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
    try:
        return G.flat_map(_IfEffect[G, L, R](on_true^, on_false^), condition^)
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)
