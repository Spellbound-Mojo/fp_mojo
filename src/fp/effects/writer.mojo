"""Writer: a base carrier of (log, value) whose log a Monoid accumulates.

A `WriterT[M, W]` value wraps M's carrier of Tuple[W.Value, A] in WriterValue.
Operations use M's own map, flat_map and map2_lazy, so over a deferred base the
result stays deferred; `run_writer` unwraps the base carrier without running
it. Logs combine in execution order.
"""
from fp.algebra._admission import _CarrierBind, _CarrierCombine
from std.builtin.rebind import rebind_var, rebind, downcast
from fp.algebra.protocols import ApplicativeError, ErrorMapping, Monad, Monoid, _Accumulate, _start_as, _combine_as
from fp.algebra.instances import IdentityFamily
from fp.callables.protocols import (BorrowCallContract, UnaryContract, BinaryContract, ThunkContract, Unary, OnceUnary, MutableUnary,
                                    OnceBinary, MutableBinary, OnceThunk)
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _unary_once_as, _binary_once_as
from std.memory import MaybeUninit
from fp.callables.products import _take_pair
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Local, Listen, Censor, _CarrierOp, _LocalLifting, WriterFamily, _WriterType
from ._adapt import _map_as
from ._transport import _BimapOp, _LocalOp, _ListenMapped, _ListenPair


comptime _Value[V: Movable & Deinitable] = downcast[V, _WriterType]
comptime _WRITER_FAMILY = "writer: value belongs to a different writer family or has incompatible base storage"


@fieldwise_init
struct WriterValue[I: WriterFamily, T: Movable & Deinitable, C: Movable & Deinitable](
    _WriterType, Copyable where conforms_to(C, Copyable)
):
    """A Writer value of family `I`: the base carrier `C` of `(log, T)`.

    Parameters:
        I: The Writer family.
        T: The payload type.
        C: The base carrier's type.
    """
    var value: Self.C
    """The base carrier of `(log, payload)`."""
    comptime Family = Self.I
    comptime Value = Self.T
    comptime Storage = Self.C
    def into_base(deinit self) -> Self.C:
        """Consume the Writer value and return its base carrier, unrun.

        Returns:
            The base carrier of `(log, payload)`.
        """
        return self.value^


def _empty_as[E: Movable & Deinitable, W: Monoid]() raises E -> W.Value where _ErrorCompatible[E, W.Error]:
    try:
        return W.empty()
    except error:
        _propagate_error[E](error^)


def _append_log_as[E: Movable & Deinitable, W: Monoid](var left: W.Value, var right: W.Value
) raises E -> W.Value where _ErrorCompatible[E, W.Error]:
    try:
        return W.combine(left^, right^)
    except error:
        _propagate_error[E](error^)


@fieldwise_init
struct _WithLog[W: Monoid, A: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Pair a base payload with the empty log."""
    comptime Arg = Self.A
    comptime Out = Tuple[Self.W.Value, Self.A]
    comptime Error = Self.W.Error
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        var log = _empty_as[Self.Error, Self.W]()
        return Tuple(log^, arg^)


@fieldwise_init
struct _MapValue[L: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Map the value of a (log, value) pair."""
    var function: Self.F
    comptime Arg = Tuple[Self.L, Self.F.Arg]
    comptime Out = Tuple[Self.L, Self.F.Out]
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        var log_slot = MaybeUninit[Self.L]()
        var value_slot = MaybeUninit[Self.F.Arg]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var value = call_once(self.function^, value_part^)
        return Tuple(log_part^, value^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        var log_slot = MaybeUninit[Self.L]()
        var value_slot = MaybeUninit[Self.F.Arg]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var value = call_repeated(self.function, value_part^)
        return Tuple(log_part^, value^)


@fieldwise_init
struct _Prepend[W: Monoid, T: Movable & Deinitable](
    OnceUnary, MutableUnary where conforms_to(W.Value, Copyable), Copyable where conforms_to(W.Value, Copyable)
):
    """Prefix the log already written to each (log, value) pair."""
    var log: Self.W.Value
    comptime Arg = Tuple[Self.W.Value, Self.T]
    comptime Out = Tuple[Self.W.Value, Self.T]
    comptime Error = Self.W.Error
    @staticmethod
    def _prepend(var prefix: Self.W.Value, var arg: Self.Arg) raises Self.Error -> Self.Out:
        var log_slot = MaybeUninit[Self.W.Value]()
        var value_slot = MaybeUninit[Self.T]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var log = _append_log_as[Self.Error, Self.W](prefix^, log_part^)
        return Tuple(log^, value_part^)
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self._prepend(self.log^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime C = downcast[Self.W.Value, Copyable & Deinitable]
        return Self._prepend(rebind_var[Self.W.Value](rebind[C](self.log).copy()), arg^)


@fieldwise_init
struct _WriterStep[I: WriterFamily, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F] and conforms_to(I.Log.Value, Copyable),
    Copyable where conforms_to(F, Copyable)
):
    """Call F with the value, then prefix the log written so far to the log of
    the Writer value it returns."""
    var function: Self.F
    comptime W = Self.I.Log
    comptime Next = _Value[Self.F.Out]
    comptime Join = _Prepend[Self.W, Self.Next.Value]
    comptime Arg = Tuple[Self.W.Value, Self.F.Arg]
    comptime Out = Self.I.Base.Mapped[Self.Next.Storage, Self.Join]
    comptime Error = _CommonError[Self.F.Error, Self.I.Base.MapError[Self.Next.Storage, Self.Join]]
    @staticmethod
    def _join(var log: Self.W.Value, var next: Self.Next) raises Self.Error -> Self.Out:
        comptime assert Self.Next.Family == Self.I, _WRITER_FAMILY
        comptime assert _ErrorCompatible[Self.Error, Self.I.Base.MapError[Self.Next.Storage, Self.Join]]
        return _map_as[Self.Error, Self.I.Base](Self.Join(log^), next^.into_base())
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error]
        var log_slot = MaybeUninit[Self.W.Value]()
        var value_slot = MaybeUninit[Self.F.Arg]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var next = rebind_var[Self.Next](_unary_once_as[Self.Error](self.function^, value_part^))
        return Self._join(log_part^, next^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error]
        var log_slot = MaybeUninit[Self.W.Value]()
        var value_slot = MaybeUninit[Self.F.Arg]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var next: Self.Next
        try:
            next = rebind_var[Self.Next](call_repeated(self.function, value_part^))
        except error:
            _propagate_error[Self.Error](error^)
        return Self._join(log_part^, next^)


@fieldwise_init
struct _WriterCombine[W: Monoid, F: BinaryContract & Movable & Deinitable](
    OnceBinary, MutableBinary where RepeatableBinary[F], Copyable where conforms_to(F, Copyable)
):
    """Combine two (log, value) pairs: logs in order, values with F."""
    var function: Self.F
    comptime First = Tuple[Self.W.Value, Self.F.First]
    comptime Second = Tuple[Self.W.Value, Self.F.Second]
    comptime Out = Tuple[Self.W.Value, Self.F.Out]
    comptime Error = _CommonError[Self.W.Error, Self.F.Error]
    def call_once(deinit self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.W.Error]
        var first_log_slot = MaybeUninit[Self.W.Value]()
        var left_slot = MaybeUninit[Self.F.First]()
        _take_pair(first^, first_log_slot, left_slot)
        var first_log = first_log_slot^.unsafe_assume_init()
        var left = left_slot^.unsafe_assume_init()
        var second_log_slot = MaybeUninit[Self.W.Value]()
        var right_slot = MaybeUninit[Self.F.Second]()
        _take_pair(second^, second_log_slot, right_slot)
        var second_log = second_log_slot^.unsafe_assume_init()
        var right = right_slot^.unsafe_assume_init()
        var log = _append_log_as[Self.Error, Self.W](first_log^, second_log^)
        var value = _binary_once_as[Self.Error](self.function^, left^, right^)
        return Tuple(log^, value^)
    def call_mut(mut self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        comptime assert RepeatableBinary[Self.F]
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.W.Error]
        var first_log_slot = MaybeUninit[Self.W.Value]()
        var left_slot = MaybeUninit[Self.F.First]()
        _take_pair(first^, first_log_slot, left_slot)
        var first_log = first_log_slot^.unsafe_assume_init()
        var left = left_slot^.unsafe_assume_init()
        var second_log_slot = MaybeUninit[Self.W.Value]()
        var right_slot = MaybeUninit[Self.F.Second]()
        _take_pair(second^, second_log_slot, right_slot)
        var second_log = second_log_slot^.unsafe_assume_init()
        var right = right_slot^.unsafe_assume_init()
        var log = _append_log_as[Self.Error, Self.W](first_log^, second_log^)
        var value: Self.F.Out
        try:
            value = call_repeated(self.function, left^, right^)
        except error:
            _propagate_error[Self.Error](error^)
        return Tuple(log^, value^)


@fieldwise_init
struct _Unwrap[G: ThunkContract & Movable & Deinitable](OnceThunk, Copyable where conforms_to(G, Copyable)):
    """Produce the right Writer value, then expose its base carrier."""
    var right: Self.G
    comptime Out = _Value[Self.G.Out].Storage
    comptime Error = Self.G.Error
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return rebind_var[_Value[Self.G.Out]](call_once(self.right^)).into_base()


@fieldwise_init
struct _UnwrapResult[I: WriterFamily, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Call F, then expose the base carrier of the Writer value it returns."""
    var function: Self.F
    comptime Next = _Value[Self.F.Out]
    comptime Arg = Self.F.Arg
    comptime Out = Self.Next.Storage
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Next.Family == Self.I, _WRITER_FAMILY
        return rebind_var[Self.Next](call_once(self.function^, arg^)).into_base()
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Next.Family == Self.I, _WRITER_FAMILY
        comptime assert RepeatableUnary[Self.F]
        return rebind_var[Self.Next](call_repeated(self.function, arg^)).into_base()


@fieldwise_init
struct _Listen[W: Monoid, T: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Expose a copy of the log next to the value."""
    comptime Arg = Tuple[Self.W.Value, Self.T]
    comptime Out = Tuple[Self.W.Value, Tuple[Self.T, Self.W.Value]]
    def call(self, var arg: Self.Arg) -> Self.Out:
        comptime assert conforms_to(Self.W.Value, Copyable), "listen: the log must be Copyable"
        comptime C = downcast[Self.W.Value, Copyable & Deinitable]
        var log_slot = MaybeUninit[Self.W.Value]()
        var value_slot = MaybeUninit[Self.T]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var log = log_part^
        var copy = rebind_var[Self.W.Value](rebind[C](log).copy())
        return Tuple(log^, Tuple(value_part^, copy^))


@fieldwise_init
struct _Censor[F: UnaryContract & Movable & Deinitable, T: Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Replace the final log with F(log)."""
    var function: Self.F
    comptime Arg = Tuple[Self.F.Arg, Self.T]
    comptime Out = Tuple[Self.F.Out, Self.T]
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        var log_slot = MaybeUninit[Self.F.Arg]()
        var value_slot = MaybeUninit[Self.T]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var log = call_once(self.function^, log_part^)
        return Tuple(log^, value_part^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        var log_slot = MaybeUninit[Self.F.Arg]()
        var value_slot = MaybeUninit[Self.T]()
        _take_pair(arg^, log_slot, value_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var value_part = value_slot^.unsafe_assume_init()
        var log = call_repeated(self.function, log_part^)
        return Tuple(log^, value_part^)


struct _WriterAcc[W: Monoid, K: _Accumulate](_Accumulate):
    """Accumulate the payloads with K and their logs in order."""
    comptime Acc = Tuple[Self.W.Value, Self.K.Acc]
    comptime Item = Tuple[Self.W.Value, Self.K.Item]
    comptime Error = _CommonError[Self.W.Error, Self.K.Error]
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        comptime assert _ErrorCompatible[Self.Error, Self.W.Error] and _ErrorCompatible[Self.Error, Self.K.Error]
        var log = _empty_as[Self.Error, Self.W]()
        return Tuple(log^, _start_as[Self.Error, Self.K]())
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return Self.K.live(acc[1])
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        comptime assert _ErrorCompatible[Self.Error, Self.W.Error] and _ErrorCompatible[Self.Error, Self.K.Error]
        if not Self.K.live(acc[1]):
            return acc^
        var log_slot = MaybeUninit[Self.W.Value]()
        var acc_slot = MaybeUninit[Self.K.Acc]()
        var next_slot = MaybeUninit[Self.W.Value]()
        var item_slot = MaybeUninit[Self.K.Item]()
        _take_pair(acc^, log_slot, acc_slot)
        var log_part = log_slot^.unsafe_assume_init()
        var acc_part = acc_slot^.unsafe_assume_init()
        _take_pair(item^, next_slot, item_slot)
        var next_part = next_slot^.unsafe_assume_init()
        var item_part = item_slot^.unsafe_assume_init()
        var log = _append_log_as[Self.Error, Self.W](log_part^, next_part^)
        return Tuple(log^, _combine_as[Self.Error, Self.K](acc_part^, item_part^))


struct WriterT[M: Monad, W: Monoid](WriterFamily, Censor, _LocalLifting, ApplicativeError where conforms_to(M, ApplicativeError), ErrorMapping where conforms_to(M, ErrorMapping)):
    """Writer over the base Monad `M`: a value is `M`'s carrier of `(log, payload)`, and the monoid `W` accumulates the log.

    Operations use the base's own `map`, `flat_map` and `map2_lazy`, so over a
    deferred base a Writer value stays deferred; logs combine in execution
    order. `pure` requires a monoid whose `empty` does not raise.

    Parameters:
        M: The base Monad.
        W: The log's monoid.
    """
    comptime Family = Self
    comptime TellAvailable = True
    comptime Told = WriterValue[Self, NoneType, Self.M.Pure[Tuple[Self.W.Value, NoneType]]]
    comptime TellError = Never
    comptime _LogCarrier[V: Movable & Deinitable] = Self.CarrierCompatible[V]
    comptime ListenCompatible[V: Movable & Deinitable] = Self._LogCarrier[V] and conforms_to(Self.W.Value, Copyable) and Self.M.MapCompatible[_Value[V].Storage, _Listen[Self.W, Self.Element[V]]]
    comptime Listened[V: Movable & Deinitable] = WriterValue[Self, Tuple[Self.Element[V], Self.W.Value], Self.M.Mapped[_Value[V].Storage, _Listen[Self.W, Self.Element[V]]]]
    comptime ListenError[V: Movable & Deinitable] = Self.M.MapError[_Value[V].Storage, _Listen[Self.W, Self.Element[V]]]
    comptime CensorCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._LogCarrier[V] and F.Arg == Self.W.Value and F.Out == Self.W.Value and Self.M.MapCompatible[_Value[V].Storage, _Censor[F, Self.Element[V]]]
    comptime Censored[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = WriterValue[Self, Self.Element[V], Self.M.Mapped[_Value[V].Storage, _Censor[F, Self.Element[V]]]]
    comptime CensorError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.MapError[_Value[V].Storage, _Censor[F, Self.Element[V]]]

    @staticmethod
    def tell(var log: Self.Log.Value) -> Self.Told:
        """Record this layer's log without constructing an empty log.

        Args:
            log: The output, consumed.

        Returns:
            A Writer carrier of NoneType.
        """
        var nothing: NoneType = None
        return Self.Told(Self.M.pure(Tuple(log^, nothing)))

    @staticmethod
    def listen[V: Movable & Deinitable](var value: V) raises Self.ListenError[V] -> Self.Listened[V]:
        """Observe this layer using the existing copy-and-pair kernel.

        Parameters:
            V: A carrier admitted by ListenCompatible.

        Args:
            value: The computation, consumed.

        Returns:
            The payload paired with a copy of its log, keeping the log.

        Raises:
            The base family's exact map error.
        """
        comptime assert Self.ListenCompatible[V]
        return Self.Listened[V](Self.M.map(_Listen[Self.W, Self.Element[V]](), rebind_var[_Value[V]](value^).into_base()))

    @staticmethod
    def censor[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.CensorError[V, F] -> Self.Censored[V, F]:
        """Transform this layer using the existing consuming log kernel.

        Parameters:
            V: A carrier of this Writer family.
            F: A callback admitted by CensorCompatible.

        Args:
            f: The log transformation, consumed.
            value: The computation, consumed.

        Returns:
            A Writer carrier with the same payload and the transformed log.

        Raises:
            The base family's exact map error.
        """
        comptime assert Self.CensorCompatible[V, F]
        return Self.Censored[V, F](Self.M.map(_Censor[F, Self.Element[V]](f^), rebind_var[_Value[V]](value^).into_base()))

    comptime _HoistCompatible[V: Movable & Deinitable, H: _CarrierOp] = Self.CarrierCompatible[V] and H.Compatible[_Value[V].Storage]
    comptime _HoistedAs[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp, Target: WriterFamily] = WriterValue[Target,A,H.Applied[_Value[V].Storage]]
    comptime _Hoisted[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = Self._HoistedAs[A,V,H,Self]
    comptime _HoistError[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = H.Error[_Value[V].Storage]
    comptime _Listening[C: Listen, A: Movable & Deinitable] = _ListenMapped[C, Tuple[Self.W.Value, A], _ListenPair[Self.W.Value, A, C.Log.Value, True]]
    @staticmethod
    def _hoist[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V) raises Self._HoistError[A, V, H] -> Self._Hoisted[A, V, H]:
        return Self._hoist_as[A,V,H,Self](op^,value^)

    @staticmethod
    def _hoist_as[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp, Target: WriterFamily](var op: H, var value: V) raises Self._HoistError[A,V,H] -> Self._HoistedAs[A,V,H,Target]:
        var base = rebind_var[_Value[V]](value^).into_base()
        return Self._HoistedAs[A,V,H,Target](op^.apply(base^))

    comptime _ScopeCompatible[C: Local, V: Movable & Deinitable] = Self.CarrierCompatible[V] and C.LocalCompatible[_Value[V].Storage]
    comptime _Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Self._Hoisted[Self.Element[V], V, _LocalOp[C, F]]
    comptime _ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = C.LocalError[_Value[V].Storage, F]

    @staticmethod
    def _scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V) raises Self._ScopeError[C, V, F] -> Self._Scoped[C, V, F]:
        """Scope the existing base storage, preserving its log and payload.

        Parameters:
            C: The selected base Local capability.
            V: This Writer family's value type.
            F: The selected environment transformation type.

        Args:
            f: The transformation, consumed.
            value: The Writer value, consumed.

        Returns:
            The rewrapped, scoped base carrier.

        Raises:
            The selected base capability's construction error.
        """
        comptime assert C.Family == Self.Base and Self._ScopeCompatible[C, V]
        return Self._hoist[Self.Element[V]](_LocalOp[C, F](f^), value^)

    comptime _Errors = downcast[Self.M, ApplicativeError]
    comptime _Mapping = downcast[Self.M, ErrorMapping]
    # Mapping does not require recovery. Both capabilities share one Failure
    # when present; an error-mapping-only base uses its own exact witness.
    comptime Failure = Self._Errors.Failure if conforms_to(Self.M, ApplicativeError) else Self._Mapping.Failure
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.CarrierCompatible[V] and Self._Errors._ErrorCarrier[_Value[V].Storage]
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = Self._Mapping.ErrorCarrierCompatible[_Value[V].Storage] if Self.CarrierCompatible[V] else False
    # A base may map into a non-Monad. Retain that real candidate for normal
    # target rejection; only an actual Monad can be wrapped in this layer.
    comptime _DefaultErrorBase[A: Movable & Deinitable, E: Movable & Deinitable] = Self._Mapping.DefaultErrorTarget[Tuple[Self.W.Value, A],E]
    comptime DefaultErrorTarget[A: Movable & Deinitable, E: Movable & Deinitable] = WriterT[downcast[Self._DefaultErrorBase[A,E],Monad],Self.W] if conforms_to(Self._DefaultErrorBase[A,E],Monad) else Self._DefaultErrorBase[A,E]
    comptime _BimapTarget[Target: ErrorMapping] = (Target == WriterT[downcast[Target, WriterFamily].Base,Self.W] and conforms_to(downcast[Target, WriterFamily].Base,ErrorMapping)) if conforms_to(Target,WriterFamily) else False
    comptime _MappingOperation[Target: ErrorMapping, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = _BimapOp[Self._Mapping,downcast[downcast[Target, WriterFamily].Base,ErrorMapping],_MapValue[Self.W.Value, F],G]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._HoistCompatible[V,Self._MappingOperation[Target,F,G]] if Self._BimapTarget[Target] else False
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._HoistedAs[F.Out,V,Self._MappingOperation[Target,F,G],downcast[Target,WriterFamily]]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._HoistError[F.Out,V,Self._MappingOperation[Target,F,G]]

    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var on_ok: F, var on_err: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        """Map one selected base outcome while retaining the exact log policy.

        Parameters:
            Target: The admitted destination with the same environment, state or log.
            V: The source carrier type, including origins.
            F: The consuming success callback type.
            G: The consuming stored-error callback type.

        Args:
            on_ok: The callback selected by an original success.
            on_err: The callback selected by an original stored error.
            source: The source carrier, consumed once.

        Returns:
            A destination Writer wrapper around the mapped, possibly deferred base.

        Raises:
            The exact base mapping construction error; deferred errors stay deferred.
        """
        comptime assert Self.BimapCompatible[Target,V,F,G]
        return Self._hoist_as[F.Out,V,Self._MappingOperation[Target,F,G],downcast[Target,WriterFamily]](Self._MappingOperation[Target,F,G](_MapValue[Self.W.Value, F](on_ok^),on_err^),source^)

    comptime Failed[A: Movable & Deinitable] = WriterValue[Self, A, Self._Errors.Failed[Tuple[Self.W.Value, A]]]
    comptime FailError[A: Movable & Deinitable] = Self._Errors.FailError[Tuple[Self.W.Value, A]]
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = WriterValue[Self, Self.Element[V], Self._Errors.Handled[_Value[V].Storage, _UnwrapResult[Self, H]]]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self._Errors.HandleError[_Value[V].Storage, _UnwrapResult[Self, H]]

    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) raises Self.FailError[A] -> Self.Failed[A]:
        """Construct a base failure without constructing an empty log.

        Parameters:
            A: The absent success payload type.

        Args:
            error: The selected base error, consumed with its exact origins.

        Returns:
            A Writer value containing the base failure, without a log payload.

        Raises:
            The base family's exact native failure-construction error.
        """
        # Normalize the capability-conditional alias without changing origins.
        comptime assert Self.Failure == Self._Errors.Failure
        return Self.Failed[A](Self._Errors.fail[Tuple[Self.W.Value, A]](rebind_var[Self._Errors.Failure](error^)))

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        """Recover the base failure with the handler's Writer value and log.

        Parameters:
            V: The Writer value of this family.
            H: The handler consuming the selected stored error and returning
                this family with the same success type; repeatable for branching.

        Args:
            handler: The handler, consumed and skipped on success.
            source: The source, consumed with its native origins.

        Returns:
            A Writer value retaining successful logs or the handler's replacement log.

        Raises:
            The base family's exact native recovery-construction error.
        """
        comptime assert Self._Handles[V, H], "or_else: Writer family or payload mismatch"
        var base = rebind_var[_Value[V]](source^).into_base()
        return Self.Handled[V, H](Self._Errors.or_else(_UnwrapResult[Self, H](handler^), base^))

    comptime Base = Self.M
    comptime Log = Self.W
    comptime Element[V: Movable & Deinitable] = _Value[V].Value
    comptime Unwrapped[V: Movable & Deinitable] = _Value[V].Storage
    """The exact base carrier returned by run_writer, including its origins."""
    @staticmethod
    def unwrap[V: Movable & Deinitable](var value: V) -> Self.Unwrapped[V]:
        """Remove an admitted Writer layer, preserving the base carrier.

        Parameters:
            V: The admitted Writer value type.

        Args:
            value: The computation, consumed.

        Returns:
            The exact base carrier; a deferred base remains unrun.
        """
        comptime assert Self.CarrierCompatible[V], _WRITER_FAMILY
        return rebind_var[_Value[V]](value^).into_base()

    comptime CarrierCompatible[V: Movable & Deinitable] = (_Value[V].Family == Self and Self.M.CarrierCompatible[_Value[V].Storage] and Self.M.Element[_Value[V].Storage] == Tuple[Self.W.Value, Self.Element[V]]) if conforms_to(V, _WriterType) else False
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[V]
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CarrierBind[Self, V, F]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = _CarrierCombine[Self, V, F, G]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[F.Out]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = WriterValue[
        Self, F.Out, Self.M.Mapped[_Value[V].Storage, _MapValue[Self.W.Value, F]]]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.MapError[
        _Value[V].Storage, _MapValue[Self.W.Value, F]]
    comptime Pure[A: Movable & Deinitable] = WriterValue[Self, A, Self.M.Pure[Tuple[Self.W.Value, A]]]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = WriterValue[
        Self, F.Out, Self.M.Combined[_Value[V].Storage, _WriterCombine[Self.W, F], _Unwrap[G]]]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Self.M.CombineError[
        _Value[V].Storage, _WriterCombine[Self.W, F], _Unwrap[G]]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = WriterValue[
        Self, _Value[F.Out].Value, Self.M.Bound[_Value[V].Storage, _WriterStep[Self, F]]]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.M.BindError[
        _Value[V].Storage, _WriterStep[Self, F]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = WriterValue[
        Self, K.Acc, Self.M._Looped[V, _UnwrapResult[Self, F], _WriterAcc[Self.W, K]]]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Self.M._LoopError[
        V, _UnwrapResult[Self, F], _WriterAcc[Self.W, K]]
    comptime _JoinCompatible[L: Movable & Deinitable, Q: Movable & Deinitable] = (Self.Element[L] == Self.Element[Q] and Self.M._JoinCompatible[_Value[L].Storage, _Value[Q].Storage]) if Self.CarrierCompatible[L] and Self.CarrierCompatible[Q] else False
    comptime _Joined[L: Movable & Deinitable, Q: Movable & Deinitable] = WriterValue[
        Self, _Value[L].Value, Self.M._Joined[_Value[L].Storage, _Value[Q].Storage]]
    comptime Lifted[V: Movable & Deinitable] = WriterValue[
        Self, Self.M.Element[V], Self.M.Mapped[V, _WithLog[Self.W, Self.M.Element[V]]]]
    comptime LiftError[V: Movable & Deinitable] = Self.M.MapError[V, _WithLog[Self.W, Self.M.Element[V]]]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Map the payload with `f`, keeping the log, through the base's `map`.

        Parameters:
            V: The Writer value's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The Writer value, consumed.

        Returns:
            The mapped Writer value.

        Raises:
            The base's `map` error, which includes the callback's.
        """
        comptime assert Self.MapCompatible[V, F], _WRITER_FAMILY
        var base = rebind_var[_Value[V]](value^).into_base()
        return Self.Mapped[V, F](Self.M.map(_MapValue[Self.W.Value, F](f^), base^))

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """A Writer value with the payload and the empty log.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            The Writer value.
        """
        comptime assert Self.W.Error == Never, "WriterT: pure requires a monoid whose empty does not raise"
        var log: Self.W.Value
        try:
            log = Self.W.empty()
        except error:
            _propagate_error[Never](error^)
        return Self.Pure[A](Self.M.pure(Tuple(log^, value^)))

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: G
    ) raises Self.CombineError[V, F, G] -> Self.Combined[V, F, G]:
        """Combine two Writer values: the logs in order, the payloads with `f`.

        Parameters:
            V: The left Writer value's type.
            F: The combiner's type.
            G: The right operand's type: a thunk producing a Writer value.

        Args:
            f: The combiner, consumed.
            left: The left Writer value, consumed.
            right: The thunk producing the right Writer value, consumed.

        Returns:
            The combined Writer value.

        Raises:
            The base's combination error, which includes the combiner's, the thunk's and the monoid's.
        """
        comptime assert Self.CombineCompatible[V, F, G], _WRITER_FAMILY
        var base = rebind_var[_Value[V]](left^).into_base()
        return Self.Combined[V, F, G](Self.M.map2_lazy(_WriterCombine[Self.W, F](f^), base^, _Unwrap[G](right^)))

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Continue with the Writer value `f` returns, appending its log to the log so far.

        Parameters:
            V: The Writer value's type.
            F: The callback's type, returning a Writer value of this family.

        Args:
            f: The callback, consumed.
            value: The Writer value, consumed.

        Returns:
            The bound Writer value.

        Raises:
            The base's bind error, which includes the callback's and the monoid's.
        """
        comptime assert Self.BindCompatible[V, F], _WRITER_FAMILY
        var base = rebind_var[_Value[V]](value^).into_base()
        return Self.Bound[V, F](Self.M.flat_map(_WriterStep[Self, F](f^), base^))

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        comptime assert _Value[F.Out].Family == Self, _WRITER_FAMILY
        return Self._Looped[V, F, K](Self.M._loop[V, _UnwrapResult[Self, F], _WriterAcc[Self.W, K]](
            _UnwrapResult[Self, F](f^), source^))

    @staticmethod
    def _join_left[L: Movable & Deinitable, Q: Movable & Deinitable](var value: L) -> Self._Joined[L, Q]:
        comptime assert _Value[L].Family == Self and _Value[Q].Family == Self, _WRITER_FAMILY
        comptime assert _Value[Q].Value == _Value[L].Value, "choice: branch payload types must agree"
        var base = rebind_var[_Value[L]](value^).into_base()
        return Self._Joined[L, Q](Self.M._join_left[_Value[L].Storage, _Value[Q].Storage](base^))

    @staticmethod
    def _join_right[L: Movable & Deinitable, Q: Movable & Deinitable](var value: Q) -> Self._Joined[L, Q]:
        comptime assert _Value[L].Family == Self and _Value[Q].Family == Self, _WRITER_FAMILY
        comptime assert _Value[Q].Value == _Value[L].Value, "choice: branch payload types must agree"
        var base = rebind_var[_Value[Q]](value^).into_base()
        return Self._Joined[L, Q](Self.M._join_right[_Value[L].Storage, _Value[Q].Storage](base^))

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) raises Self.LiftError[V] -> Self.Lifted[V]:
        """A Writer value with a base carrier's payload and the empty log.

        Parameters:
            V: The base carrier's type.

        Args:
            value: The base carrier, consumed.

        Returns:
            The Writer value.

        Raises:
            The monoid's `empty` error, through the base's `map`.
        """
        return Self.Lifted[V](Self.M.map(_WithLog[Self.W, Self.M.Element[V]](), value^))


comptime Writer[W: Monoid] = WriterT[IdentityFamily, W]
"""Writer over the bare value: a value is `(log, payload)`.

Parameters:
    W: The log's monoid.
"""


def writer[C: Movable & Deinitable, //, I: WriterFamily, T: Movable & Deinitable](var carrier: C) -> WriterValue[I, T, C] where I.CarrierCompatible[WriterValue[I, T, C]]:
    """Make a Writer value from a base carrier whose payload is exactly `(log, value)`.

    Parameters:
        C: The base carrier's type.
        I: The Writer family.
        T: The payload type.

    Args:
        carrier: The base carrier, consumed.

    Returns:
        The Writer value.
    """
    comptime assert I.CarrierCompatible[WriterValue[I, T, C]], "writer: base payload must be (log, value)"
    return WriterValue[I, T, C](carrier^)


# Like `run`, these entries admit a value named through a family's aliases in
# generic code, which is only known to be Movable & Deinitable.
def run_writer[V: Movable & Deinitable, //, I: WriterFamily](var value: V) -> I.Unwrapped[V] where I.CarrierCompatible[V]:
    """Remove the Writer layer and return the base carrier of `(log, value)`; a deferred base is returned unrun.

    Parameters:
        V: The Writer value's type.
        I: The Writer family.

    Args:
        value: The Writer value, consumed.

    Returns:
        The base carrier.
    """
    return I.unwrap(value^)


# Preserve the original import paths; capabilities owns the checked entries.
from .capabilities import tell, listen, censor
