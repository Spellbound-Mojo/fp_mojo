"""OptionalT and ResultT: a base carrier of Optional[A] or Result[A, E].

A layer value is the base carrier itself and runs with the base's `run`. `map`
maps the inner carrier through the inner family's own `map`. `flat_map` and
`map2_lazy` bind the base: an absent value or a stored error skips the callback
and the right operand, keeping the base's earlier effects. The right operand is
produced at most once. Over IdentityFamily the aliases are the native Optional
and Result families.
"""

from fp.algebra._branches import _OptionalGuard, _ResultGuard
from fp.algebra._result_accumulation import _ResultAccumulator, _FirstError
from fp.algebra._admission import _CarrierBind, _CarrierCombine
from std.builtin.rebind import rebind_var, rebind, downcast
from fp.algebra.protocols import (_pure, Monad, Applicative, ApplicativeError, ErrorMapping, _CALLBACK_ADMISSION, _RecoveryShape, _MappedFamily, _Lifting, _Accumulate, _Append, _Present, _BindFirst, _Lazy, _UnaryView)
from fp.algebra._contracts import MapContract, BindContract
from fp.algebra.error_mapping import MapBothContract
from fp.algebra.instances import IdentityFamily, OptionalFamily, ResultFamily, _OkOf
from fp.callables.protocols import BorrowCallContract, UnaryContract, BinaryContract, ThunkContract, OnceUnary, MutableUnary
from fp.callables.invoke import _OnceBinaryAvailable, _OnceThunkAvailable, RepeatableUnary
from fp.data._result import Result, Ok, Err
from fp._internal.errors import _CommonErrorCompatible, _CommonError, _ErrorCompatible
from .protocols import Local, Listen, _CarrierOp, _LocalLifting, _CapabilityLifting, _CarrierLifting
from ._adapt import _map_as
from ._transport import _LocalOp, _ListenMapped, _ListenSum


comptime _LAYER = _CALLBACK_ADMISSION
comptime _LAYER_BIND = _CALLBACK_ADMISSION


@fieldwise_init
struct _InnerMap[N: Applicative, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Map a layer's inner Optional or Result carrier with the inner family."""
    var function: Self.F
    comptime Arg = Self.N.Pure[Self.F.Arg]
    comptime _Map = MapContract[Self.N, Self.Arg, Self.F]
    comptime Out = Self._Map.Out
    comptime Error = Self._Map.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self.N.map(self.function^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        comptime View = _UnaryView[Self.F, origin_of(self.function)]
        comptime assert Self.N.Mapped[Self.Arg, View] == Self.Out
        comptime assert _ErrorCompatible[Self.Error, Self.N.MapError[Self.Arg, View]]
        return rebind_var[Self.Out](_map_as[Self.Error, Self.N](View(Pointer(to=self.function)), arg^))


@fieldwise_init
struct _InnerBimap[E: Movable & Deinitable,
                   F: UnaryContract & Movable & Deinitable,
                   G: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F] and RepeatableUnary[G],
    Copyable where conforms_to(F, Copyable) and conforms_to(G, Copyable)
):
    """One base-map callback; Result remains the owner of its original branch."""
    var on_ok: Self.F
    var on_err: Self.G
    comptime Arg = Result[Self.F.Arg,Self.E]
    comptime Inner = ResultFamily[Self.E]
    comptime Target = ResultFamily[Self.G.Out]
    comptime Operation = MapBothContract[Self.Inner,Self.Arg,Self.F,Self.G,Self.Target]
    comptime Out = Self.Operation.Out
    comptime Error = Self.Operation.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self.Inner.bimap[Self.Target](self.on_ok^,self.on_err^,arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F] and RepeatableUnary[Self.G]
        var on_ok = _UnaryView[Self.F,origin_of(self.on_ok)](Pointer(to=self.on_ok))
        var on_err = _UnaryView[Self.G,origin_of(self.on_err)](Pointer(to=self.on_err))
        return Self.Inner.bimap[Self.Target](on_ok^,on_err^,arg^)


@fieldwise_init
struct _LayerRight[M: Monad, N: Applicative, F: BinaryContract & Movable & Deinitable,
                   G: ThunkContract & Movable & Deinitable](
    OnceUnary, MutableUnary where conforms_to(F, Copyable) and conforms_to(G.Out, Copyable)
):
    """Produce a lazy right operand and map combination over its inner layer.

    Existing Optional/Result guards own skipped branches and base joins. This
    continuation alone owns the cached right operand and callback copying.
    """
    var function: Self.F
    var right: _Lazy[Self.G]
    comptime Apply = _InnerMap[Self.N, _BindFirst[Self.F]]
    comptime _Map = MapContract[Self.M, Self.G.Out, Self.Apply]
    comptime Arg = Self.F.First
    comptime Out = Self._Map.Out
    comptime Error = _CommonError[Self.G.Error, Self._Map.Error]
    comptime Compatible = (
        _OnceBinaryAvailable[Self.F] and _OnceThunkAvailable[Self.G] and
        Self._Map.FamilyCompatible and
        _CommonErrorCompatible[Self.G.Error,Self._Map.Error]
    )
    @staticmethod
    def _apply(var function: Self.F, var first: Self.Arg, var right: Self.G.Out) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self._Map.Error]
        return _map_as[Self.Error, Self.M](Self.Apply(_BindFirst[Self.F](function^, first^)), right^)
    def call_once(deinit self, var first: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        var right = self.right^.take[Self.Error]()
        return Self._apply(self.function^, first^, right^)
    def call_mut(mut self, var first: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert conforms_to(Self.F, Copyable), "map2: repeated branches copy the callback and the right operand"
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        var right = self.right.copy_value[Self.Error]()
        comptime C = downcast[Self.F, Copyable & Deinitable]
        var function = rebind_var[Self.F](rebind[C](self.function).copy())
        return Self._apply(function^, first^, right^)


comptime _OptionalCombine[M: Monad, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = _OptionalGuard[M, _LayerRight[M, OptionalFamily, F, G]]
comptime _ResultCombine[M: Monad, E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = _ResultGuard[M, E, _LayerRight[M, ResultFamily[E], F, G]]


struct _OptionalAcc[K: _Accumulate](_Accumulate):
    """Accumulate inside Optional: the first absent payload ends accumulation."""
    comptime Acc = Optional[Self.K.Acc]
    comptime Item = Optional[Self.K.Item]
    comptime Error = Self.K.Error
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        return Optional(Self.K.start())
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return Bool(acc) and Self.K.live(acc.value())
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        if not Self.live(acc):
            return acc^
        if not item:
            return Optional[Self.K.Acc]()
        return Optional(Self.K.combine(acc.unsafe_take(), item.unsafe_take()))


# Layers and native Result loops share the same first-error accumulation owner.
comptime _ResultAcc[K: _Accumulate, E: Movable & Deinitable] = _ResultAccumulator[K, _FirstError[E]]


struct _LayerTransport[I: Monad & _CapabilityLifting]:
    """Transport operations through layers represented directly by a base carrier.

    OptionalT and ResultT keep the base carrier's storage and error types.
    This owner shares their representation policy and consumes each operation
    once; wrapped or deferred representations define their own transport.
    """
    comptime HoistCompatible[V: Movable & Deinitable, H: _CarrierOp] = Self.I.CarrierCompatible[V] and H.Compatible[V]
    comptime Hoisted[V: Movable & Deinitable, H: _CarrierOp] = H.Applied[V]
    comptime HoistError[V: Movable & Deinitable, H: _CarrierOp] = H.Error[V]
    @staticmethod
    def hoist[V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V) raises Self.HoistError[V,H] -> Self.Hoisted[V,H]:
        return op^.apply(value^)

    comptime ScopeCompatible[C: Local, V: Movable & Deinitable] = Self.I.CarrierCompatible[V] and C.LocalCompatible[V]
    comptime Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Self.Hoisted[V, _LocalOp[C,F]]
    comptime ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = C.LocalError[V,F]
    @staticmethod
    def scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V) raises Self.ScopeError[C,V,F] -> Self.Scoped[C,V,F]:
        comptime assert C.Family == Self.I.Base and Self.ScopeCompatible[C,V]
        return Self.hoist(_LocalOp[C,F](f^),value^)


# Concrete family declarations retain their native capability signatures;
# the shared representation policy and execution live in _LayerTransport.
struct _OptionalT[M: Monad](Monad, _LocalLifting, _CarrierLifting, ApplicativeError where conforms_to(M, ApplicativeError), ErrorMapping where conforms_to(M, ErrorMapping)):
    """OptionalT over a base other than Identity: a value is M's carrier of Optional[A]."""
    comptime _HoistCompatible[V: Movable & Deinitable, H: _CarrierOp] = _LayerTransport[Self].HoistCompatible[V,H]
    comptime _Hoisted[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = _LayerTransport[Self].Hoisted[V,H]
    comptime _HoistError[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = _LayerTransport[Self].HoistError[V,H]
    comptime _Listening[C: Listen, A: Movable & Deinitable] = _ListenMapped[C, Optional[A], _ListenSum[OptionalFamily, A, C.Log.Value]]
    @staticmethod
    def _hoist[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V) raises Self._HoistError[A, V, H] -> Self._Hoisted[A, V, H]:
        return _LayerTransport[Self].hoist(op^,value^)

    comptime _ScopeCompatible[C: Local, V: Movable & Deinitable] = _LayerTransport[Self].ScopeCompatible[C,V]
    comptime _Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = _LayerTransport[Self].Scoped[C,V,F]
    comptime _ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = _LayerTransport[Self].ScopeError[C,V,F]
    @staticmethod
    def _scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V) raises Self._ScopeError[C, V, F] -> Self._Scoped[C, V, F]:
        return _LayerTransport[Self].scope[C](f^,value^)

    comptime _Mapping = downcast[Self.M,ErrorMapping]
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = Self.CarrierCompatible[V] and Self._Mapping.ErrorCarrierCompatible[V]
    comptime _ErrorTargetBase[A: Movable & Deinitable, E: Movable & Deinitable] = Self._Mapping.DefaultErrorTarget[Optional[A],E]
    # Preserve an unwrappable base candidate for ordinary layer-policy rejection.
    comptime DefaultErrorTarget[A: Movable & Deinitable, E: Movable & Deinitable] = (
        _OptionalT[downcast[Self._ErrorTargetBase[A,E],Monad & ErrorMapping]]
        if conforms_to(Self._ErrorTargetBase[A,E],Monad) else Self._ErrorTargetBase[A,E]
    )
    # Reuse layer metadata, but require the exact OptionalT constructor before
    # allowing the base to decide a source-to-target policy transition.
    comptime _TargetBase[Target: ErrorMapping] = downcast[downcast[Target,_CapabilityLifting].Base,Monad & ErrorMapping]
    comptime _BimapOp[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = MapBothContract[Self._Mapping,V,_InnerMap[OptionalFamily,F],G,Self._TargetBase[Target]]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = (
        (Target == OptionalT[Self._TargetBase[Target]] and
         Self._BimapOp[Target,V,F,G].Compatible)
        if conforms_to(Target,_CapabilityLifting) and conforms_to(downcast[Target,_CapabilityLifting].Base,ErrorMapping) else False
    )
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._BimapOp[Target,V,F,G].Out
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._BimapOp[Target,V,F,G].Error
    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var on_ok: F, var on_err: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        comptime assert Self.BimapCompatible[Target,V,F,G]
        return Self._Mapping.bimap[Self._TargetBase[Target]](_InnerMap[OptionalFamily,F](on_ok^),on_err^,source^)

    comptime _Errors = downcast[Self.M, ApplicativeError]
    comptime Failure = Self._Mapping.Failure if conforms_to(Self.M,ErrorMapping) else Self._Errors.Failure
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.CarrierCompatible[V] and Self._Errors._ErrorCarrier[V]
    comptime _Handles[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Bool = (Self._Errors._Handles[V,H] if _RecoveryShape[Self,Self.Failure,V,H,Self._ErrorCarrier[V],Self._ErrorCarrier[H.Out]] else False) if conforms_to(Self.M,ApplicativeError) else False
    comptime Failed[A: Movable & Deinitable] = Self._Errors.Failed[Optional[A]]
    comptime FailError[A: Movable & Deinitable] = Self._Errors.FailError[Optional[A]]
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self._Errors.Handled[V, H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self._Errors.HandleError[V, H]

    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) raises Self.FailError[A] -> Self.Failed[A]:
        comptime assert Self.Failure == Self._Errors.Failure
        return Self._Errors.fail[Optional[A]](rebind_var[Self._Errors.Failure](error^))

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        comptime assert Self._Handles[V, H], "or_else: OptionalT family or payload mismatch"
        return Self._Errors.or_else(handler^, source^)

    comptime Base = Self.M
    comptime _Wrapped[A: Movable & Deinitable] = Optional[A]
    comptime Element[V: Movable & Deinitable] = OptionalFamily.Element[Self.M.Element[V]]
    comptime CarrierCompatible[V: Movable & Deinitable] = Self.M.CarrierCompatible[V] and OptionalFamily.CarrierCompatible[Self.M.Element[V]]
    # One operation descriptor fixes the callback used by admission and types.
    comptime _MapOp[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = MapContract[Self.M,V,_InnerMap[OptionalFamily,F]]
    comptime _BindOp[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = BindContract[Self.M,V,_OptionalGuard[Self.M,F]]
    comptime _CombineOp[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = BindContract[Self.M,V,_OptionalCombine[Self.M,F,G]]
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._MapOp[V,F].FamilyCompatible if Self.CarrierCompatible[V] else False
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._BindOp[V,F].FamilyCompatible if _CarrierBind[Self,V,F] else False
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = (
        _LayerRight[Self.M,OptionalFamily,F,G].Compatible and Self._CombineOp[V,F,G].FamilyCompatible
    ) if _CarrierCombine[Self,V,F,G] else False
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._LoopCompatible[V, F, _Append[Self.Element[F.Out]]] if Self.CarrierCompatible[F.Out] else False
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._MapOp[V,F].Out
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._MapOp[V,F].Error
    comptime Pure[A: Movable & Deinitable] = Self.M.Pure[Optional[A]]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self._CombineOp[V,F,G].Out
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self._CombineOp[V,F,G].Error
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._BindOp[V,F].Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._BindOp[V,F].Error
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._LoopCompatible[V, F, _OptionalAcc[K]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._Looped[V, F, _OptionalAcc[K]]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._LoopError[V, F, _OptionalAcc[K]]
    comptime _JoinCompatible[L: Movable & Deinitable, Q: Movable & Deinitable] = Self.CarrierCompatible[L] and Self.CarrierCompatible[Q] and Self.M._JoinCompatible[L, Q]
    comptime _Joined[L: Movable & Deinitable, Q: Movable & Deinitable] = Self.M._Joined[L, Q]
    comptime _LiftOp[V: Movable & Deinitable] = MapContract[Self.M,V,_Present[Self.M.Element[V]]]
    comptime Lifted[V: Movable & Deinitable] = Self._LiftOp[V].Out
    comptime LiftError[V: Movable & Deinitable] = Self._LiftOp[V].Error

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        comptime assert Self.MapCompatible[V, F], _LAYER
        return Self.M.map(_InnerMap[OptionalFamily, F](f^), value^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return _pure[Self.M](Optional(value^))

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: G
    ) raises Self.CombineError[V, F, G] -> Self.Combined[V, F, G]:
        comptime assert Self.CombineCompatible[V, F, G], _LAYER
        return Self.M.flat_map(_OptionalCombine[Self.M, F, G](_LayerRight[Self.M, OptionalFamily, F, G](f^, _Lazy[G](right^))), left^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        comptime assert Self.BindCompatible[V, F], _LAYER_BIND
        return Self.M.flat_map(_OptionalGuard[Self.M, F](f^), value^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        return Self.M._loop[V, F, _OptionalAcc[K]](f^, source^)

    @staticmethod
    def _join_left[L: Movable & Deinitable, Q: Movable & Deinitable](var value: L) -> Self._Joined[L, Q]:
        return Self.M._join_left[L, Q](value^)

    @staticmethod
    def _join_right[L: Movable & Deinitable, Q: Movable & Deinitable](var value: Q) -> Self._Joined[L, Q]:
        return Self.M._join_right[L, Q](value^)

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) raises Self.LiftError[V] -> Self.Lifted[V]:
        return Self.M.map(_Present[Self.M.Element[V]](), value^)


struct _ResultT[M: Monad, E: Movable & Deinitable](Monad, ApplicativeError, ErrorMapping, _LocalLifting, _CarrierLifting):
    """ResultT over a base other than Identity: a value is M's carrier of Result[A, E]."""
    comptime _HoistCompatible[V: Movable & Deinitable, H: _CarrierOp] = _LayerTransport[Self].HoistCompatible[V,H]
    comptime _Hoisted[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = _LayerTransport[Self].Hoisted[V,H]
    comptime _HoistError[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = _LayerTransport[Self].HoistError[V,H]
    comptime _Listening[C: Listen, A: Movable & Deinitable] = _ListenMapped[C, Result[A, Self.E], _ListenSum[ResultFamily[Self.E], A, C.Log.Value]]
    @staticmethod
    def _hoist[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V) raises Self._HoistError[A, V, H] -> Self._Hoisted[A, V, H]:
        return _LayerTransport[Self].hoist(op^,value^)

    comptime _ScopeCompatible[C: Local, V: Movable & Deinitable] = _LayerTransport[Self].ScopeCompatible[C,V]
    comptime _Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = _LayerTransport[Self].Scoped[C,V,F]
    comptime _ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = _LayerTransport[Self].ScopeError[C,V,F]
    @staticmethod
    def _scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V) raises Self._ScopeError[C, V, F] -> Self._Scoped[C, V, F]:
        return _LayerTransport[Self].scope[C](f^,value^)

    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = Self.CarrierCompatible[V]
    # Error rebinding changes this inner Result; the base keeps its policy and
    # only reselects payload-dependent metadata through its existing owner.
    comptime _ErrorTargetBase[A: Movable & Deinitable, U: Movable & Deinitable] = _MappedFamily[Self.M,Result[A,U]]
    comptime DefaultErrorTarget[A: Movable & Deinitable, U: Movable & Deinitable] = (
        ResultT[downcast[Self._ErrorTargetBase[A,U],Monad],U]
        if conforms_to(Self._ErrorTargetBase[A,U],Monad) else ResultT[Self.M,U]
    )
    # A non-Monad rebound retains a real candidate without inventing capability;
    # raw-base admission below rejects it even when the stored error is unchanged.
    comptime _BimapOp[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = MapContract[Self.M,V,_InnerBimap[Self.E,F,G]]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = (
        (Target == Self.DefaultErrorTarget[F.Out,G.Out] and
         _InnerBimap[Self.E,F,G].Operation.Compatible and
         Self._BimapOp[V,F,G].Compatible)
        if conforms_to(Self._ErrorTargetBase[F.Out,G.Out],Monad) else False
    )
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._BimapOp[V,F,G].Out
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._BimapOp[V,F,G].Error
    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var on_ok: F, var on_err: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        comptime assert Self.BimapCompatible[Target,V,F,G]
        return Self.M.map(_InnerBimap[Self.E,F,G](on_ok^,on_err^),source^)

    comptime Failure = Self.E
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.CarrierCompatible[V]
    comptime _Handles[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Bool = Self.M.BindCompatible[V,_ResultGuard[Self.M,Self.E,H,False]] if _RecoveryShape[Self,Self.Failure,V,H,Self._ErrorCarrier[V],Self._ErrorCarrier[H.Out]] else False
    comptime Failed[A: Movable & Deinitable] = Self.M.Pure[Result[A, Self.E]]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.M.Bound[V, _ResultGuard[Self.M, Self.E, H, False]]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.M.BindError[V, _ResultGuard[Self.M, Self.E, H, False]]

    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) -> Self.Failed[A]:
        return _pure[Self.M](ResultFamily[Self.E].fail[A](error^))

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V
    ) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        comptime assert Self._Handles[V, H], "or_else: handler must retain success and stored-error types"
        return Self.M.flat_map(_ResultGuard[Self.M, Self.E, H, False](handler^), source^)

    comptime Base = Self.M
    comptime _Wrapped[A: Movable & Deinitable] = Result[A, Self.E]
    comptime Element[V: Movable & Deinitable] = ResultFamily[Self.E].Element[Self.M.Element[V]]
    comptime CarrierCompatible[V: Movable & Deinitable] = Self.M.CarrierCompatible[V] and ResultFamily[Self.E].CarrierCompatible[Self.M.Element[V]]
    # One operation descriptor fixes the callback used by admission and types.
    comptime _MapOp[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = MapContract[Self.M,V,_InnerMap[ResultFamily[Self.E],F]]
    comptime _BindOp[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = BindContract[Self.M,V,_ResultGuard[Self.M,Self.E,F]]
    comptime _CombineOp[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = BindContract[Self.M,V,_ResultCombine[Self.M,Self.E,F,G]]
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._MapOp[V,F].FamilyCompatible if Self.CarrierCompatible[V] else False
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._BindOp[V,F].FamilyCompatible if _CarrierBind[Self,V,F] else False
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = (
        _LayerRight[Self.M,ResultFamily[Self.E],F,G].Compatible and Self._CombineOp[V,F,G].FamilyCompatible
    ) if _CarrierCombine[Self,V,F,G] else False
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._LoopCompatible[V, F, _Append[Self.Element[F.Out]]] if Self.CarrierCompatible[F.Out] else False
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._MapOp[V,F].Out
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._MapOp[V,F].Error
    comptime Pure[A: Movable & Deinitable] = Self.M.Pure[Result[A, Self.E]]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self._CombineOp[V,F,G].Out
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self._CombineOp[V,F,G].Error
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._BindOp[V,F].Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._BindOp[V,F].Error
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._LoopCompatible[V, F, _ResultAcc[K, Self.E]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._Looped[V, F, _ResultAcc[K, Self.E]]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._LoopError[V, F, _ResultAcc[K, Self.E]]
    comptime _JoinCompatible[L: Movable & Deinitable, Q: Movable & Deinitable] = Self.CarrierCompatible[L] and Self.CarrierCompatible[Q] and Self.M._JoinCompatible[L, Q]
    comptime _Joined[L: Movable & Deinitable, Q: Movable & Deinitable] = Self.M._Joined[L, Q]
    comptime _LiftOp[V: Movable & Deinitable] = MapContract[Self.M,V,_OkOf[Self.M.Element[V], Self.E]]
    comptime Lifted[V: Movable & Deinitable] = Self._LiftOp[V].Out
    comptime LiftError[V: Movable & Deinitable] = Self._LiftOp[V].Error

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        comptime assert Self.MapCompatible[V, F], _LAYER
        return Self.M.map(_InnerMap[ResultFamily[Self.E], F](f^), value^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return _pure[Self.M](Result[A, Self.E](Ok(value^)))

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: G
    ) raises Self.CombineError[V, F, G] -> Self.Combined[V, F, G]:
        comptime assert Self.CombineCompatible[V, F, G], _LAYER
        return Self.M.flat_map(_ResultCombine[Self.M, Self.E, F, G](_LayerRight[Self.M, ResultFamily[Self.E], F, G](f^, _Lazy[G](right^))), left^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        comptime assert Self.BindCompatible[V, F], _LAYER_BIND
        return Self.M.flat_map(_ResultGuard[Self.M, Self.E, F](f^), value^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        return Self.M._loop[V, F, _ResultAcc[K, Self.E]](f^, source^)

    @staticmethod
    def _join_left[L: Movable & Deinitable, Q: Movable & Deinitable](var value: L) -> Self._Joined[L, Q]:
        return Self.M._join_left[L, Q](value^)

    @staticmethod
    def _join_right[L: Movable & Deinitable, Q: Movable & Deinitable](var value: Q) -> Self._Joined[L, Q]:
        return Self.M._join_right[L, Q](value^)

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) raises Self.LiftError[V] -> Self.Lifted[V]:
        return Self.M.map(_OkOf[Self.M.Element[V], Self.E](), value^)


comptime OptionalT[M: Monad]: Monad & _Lifting = OptionalFamily if M == IdentityFamily else _OptionalT[M]
"""Optional over the base Monad `M`: a value is `M`'s carrier of `Optional[A]`; over Identity, `OptionalFamily`.

A value is the base carrier itself, run with the base's `run`. An absent value
skips later callbacks and right operands and keeps the base's earlier effects.

Parameters:
    M: The base Monad.
"""

comptime ResultT[M: Monad, E: Movable & Deinitable]: Monad & ApplicativeError & ErrorMapping & _Lifting = ResultFamily[E] if M == IdentityFamily else _ResultT[M, E]
"""Result over the base Monad `M`: a value is `M`'s carrier of `Result[A, E]`; over Identity, `ResultFamily[E]`.

A stored error skips later callbacks and right operands and keeps the base's
earlier effects; it is never converted into an absence, nor a native error.

Parameters:
    M: The base Monad.
    E: The stored error type.
"""
