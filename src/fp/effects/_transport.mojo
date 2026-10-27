"""Carrier operations and payload rearrangement shared by capability lifting.

Operations select a capability; representations own when and how the base
carrier is reached. No operation here runs a Reader or threads a State.
"""
from std.builtin.rebind import rebind_var
from std.memory import MaybeUninit
from fp.algebra.protocols import Monad, ErrorMapping
from fp.algebra.error_mapping import MapBothContract, _map_both
from fp.callables.protocols import BorrowCallContract, UnaryContract, Unary
from fp.callables.products import _take_pair, _WithSecond
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Local, Listen, Censor, _CarrierOp
from ._adapt import _local_as, _map_as


@fieldwise_init
struct _BimapOp[M: ErrorMapping, N: ErrorMapping,
                F: UnaryContract & Movable & Deinitable,
                G: UnaryContract & Movable & Deinitable](
    _CarrierOp, Copyable where conforms_to(F, Copyable) and conforms_to(G, Copyable)
):
    """Map the selected base outcome once; transport owns reaching its carrier."""
    var on_ok: Self.F
    var on_err: Self.G
    comptime Contract[V: Movable & Deinitable] = MapBothContract[Self.M,V,Self.F,Self.G,Self.N]
    comptime Compatible[V: Movable & Deinitable] = Self.Contract[V].Compatible
    comptime Applied[V: Movable & Deinitable] = Self.Contract[V].Out
    comptime Error[V: Movable & Deinitable] = Self.Contract[V].Error
    def apply[V: Movable & Deinitable](deinit self, var value: V) raises Self.Error[V] -> Self.Applied[V]:
        comptime assert Self.Compatible[V]
        return _map_both[Self.M,V,Self.F,Self.G,Self.N](self.on_ok^,self.on_err^,value^)


@fieldwise_init
struct _LocalOp[C: Local, F: BorrowCallContract & Movable & Deinitable](
    _CarrierOp, Copyable where conforms_to(F, Copyable)
):
    var function: Self.F
    comptime Compatible[V: Movable & Deinitable] = Self.C.LocalCompatible[V] and Self.F.Payload == Self.C.Environment and Self.F.Result == Self.C.Environment
    comptime Applied[V: Movable & Deinitable] = Self.C.Localized[V, Self.F]
    comptime Error[V: Movable & Deinitable] = Self.C.LocalError[V, Self.F]
    def apply[V: Movable & Deinitable](deinit self, var value: V) raises Self.Error[V] -> Self.Applied[V]:
        comptime assert Self.Compatible[V]
        return _local_as[Self.Error[V], Self.C](self.function^, value^)


@fieldwise_init
struct _ListenOp[C: Listen](_CarrierOp, Copyable, Defaultable):
    comptime Compatible[V: Movable & Deinitable] = Self.C.ListenCompatible[V]
    comptime Applied[V: Movable & Deinitable] = Self.C.Listened[V]
    comptime Error[V: Movable & Deinitable] = Self.C.ListenError[V]
    def apply[V: Movable & Deinitable](deinit self, var value: V) raises Self.Error[V] -> Self.Applied[V]:
        comptime assert Self.Compatible[V]
        return Self.C.listen(value^)


@fieldwise_init
struct _CensorOp[C: Censor, F: UnaryContract & Movable & Deinitable](
    _CarrierOp, Copyable where conforms_to(F, Copyable)
):
    var function: Self.F
    comptime Compatible[V: Movable & Deinitable] = Self.C.CensorCompatible[V, Self.F] and Self.F.Arg == Self.C.Log.Value and Self.F.Out == Self.C.Log.Value
    comptime Applied[V: Movable & Deinitable] = Self.C.Censored[V, Self.F]
    comptime Error[V: Movable & Deinitable] = Self.C.CensorError[V, Self.F]
    def apply[V: Movable & Deinitable](deinit self, var value: V) raises Self.Error[V] -> Self.Applied[V]:
        comptime assert Self.Compatible[V]
        return Self.C.censor(self.function^, value^)


@fieldwise_init
struct _ListenMapped[C: Listen, P: Movable & Deinitable, F: UnaryContract & Movable & Deinitable & Defaultable](_CarrierOp, Copyable, Defaultable):
    """Listen once, then rearrange only the layer's payload structure."""
    comptime M = Self.C.Family
    comptime Applied[V: Movable & Deinitable] = Self.M.Mapped[Self.C.Listened[V], Self.F]
    comptime Error[V: Movable & Deinitable] = _CommonError[Self.C.ListenError[V], Self.M.MapError[Self.C.Listened[V], Self.F]]
    comptime _SourceCompatible[V: Movable & Deinitable] = Self.C.ListenCompatible[V]
    # Check the original payload separately: Mojo 1.1 cannot reliably reduce
    # Element[Listened[V]] inside this generic admission predicate. Listen
    # supplies (P, Log.Value) by contract; no runtime origin is relabeled.
    comptime _InputCompatible[V: Movable & Deinitable] = Self.M.Element[V] == Self.P and Self.F.Arg == Tuple[Self.P, Self.C.Log.Value]
    comptime _MapCompatible[V: Movable & Deinitable] = Self.M.MapCompatible[Self.C.Listened[V], Self.F]
    comptime _ErrorsCompatible[V: Movable & Deinitable] = _ErrorCompatible[Self.Error[V], Self.M.MapError[Self.C.Listened[V], Self.F]]
    comptime Compatible[V: Movable & Deinitable] = Self._SourceCompatible[V] and Self._InputCompatible[V] and Self._MapCompatible[V] and Self._ErrorsCompatible[V]
    def apply[V: Movable & Deinitable](deinit self, var value: V) raises Self.Error[V] -> Self.Applied[V]:
        comptime assert Self.Compatible[V]
        comptime E = Self.Error[V]
        comptime assert _ErrorCompatible[E, Self.C.ListenError[V]] and _ErrorCompatible[E, Self.M.MapError[Self.C.Listened[V], Self.F]]
        var heard: Self.C.Listened[V]
        try: heard = Self.C.listen(value^)
        except error: _propagate_error[E](error^)
        return _map_as[E, Self.M](Self.F(), heard^)


@fieldwise_init
struct _ListenPair[X: Movable & Deinitable, A: Movable & Deinitable, L: Movable & Deinitable, first: Bool](Unary, Copyable, Defaultable):
    """Move a listened log beside the payload, preserving an outer log or state."""
    comptime Left = Self.X if Self.first else Self.A
    comptime Right = Self.A if Self.first else Self.X
    comptime Pair = Tuple[Self.Left, Self.Right]
    comptime Arg = Tuple[Self.Pair, Self.L]
    comptime Out = Tuple[Self.X, Tuple[Self.A, Self.L]] if Self.first else Tuple[Tuple[Self.A, Self.L], Self.X]
    def call(self, var arg: Self.Arg) -> Self.Out:
        var pair_slot = MaybeUninit[Self.Pair]()
        var log_slot = MaybeUninit[Self.L]()
        _take_pair(arg^, pair_slot, log_slot)
        var pair = pair_slot^.unsafe_assume_init()
        var log = log_slot^.unsafe_assume_init()
        var left_slot = MaybeUninit[Self.Left]()
        var right_slot = MaybeUninit[Self.Right]()
        _take_pair(pair^, left_slot, right_slot)
        var left = left_slot^.unsafe_assume_init()
        var right = right_slot^.unsafe_assume_init()
        comptime if Self.first:
            return rebind_var[Self.Out](Tuple(left^, Tuple(right^, log^)))
        else:
            return rebind_var[Self.Out](Tuple(Tuple(left^, log^), right^))


@fieldwise_init
struct _ListenSum[N: Monad, A: Movable & Deinitable, L: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Move the observed log into a present/Ok payload via the sum's own map."""
    comptime Arg = Tuple[Self.N.Pure[Self.A], Self.L]
    comptime Pair = _WithSecond[Self.A, Self.L]
    comptime Out = Self.N.Mapped[Self.N.Pure[Self.A], Self.Pair]
    comptime Error = Self.N.MapError[Self.N.Pure[Self.A], Self.Pair]
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        var value_slot = MaybeUninit[Self.N.Pure[Self.A]]()
        var log_slot = MaybeUninit[Self.L]()
        _take_pair(arg^, value_slot, log_slot)
        var value = value_slot^.unsafe_assume_init()
        var log = log_slot^.unsafe_assume_init()
        return Self.N.map(Self.Pair(log^), value^)
