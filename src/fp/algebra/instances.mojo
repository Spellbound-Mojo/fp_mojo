"""Static instances for native values; container storage is never replaced.

Identity is the bare value; Optional, Result and List keep their own storage.
Result transformations use the owned transformation of the Result methods.
"""

from std.builtin.rebind import rebind_var, rebind, downcast
from std.iter import IterableOwned, Iterator
from fp.callables.protocols import BorrowCallContract, UnaryContract, BinaryContract, ThunkContract, Unary, BorrowCallable
from fp.callables.invoke import RepeatableUnary, RepeatableBinary, _OnceUnaryAvailable, _OnceThunkAvailable, call_once, call_repeated
from fp.callables._receiver import _unary_once_as, _binary_once_as, _binary_repeated_as, _thunk_once_as
from fp.data._result import Result, Ok, Err, _ResultType, _transform_result_owned
from fp.iteration._advance import _next_optional
from fp.iteration._terminal import _append
from fp._internal.errors import _CommonErrorCompatible, _CommonError, _ErrorCompatible, _propagate_error
from fp.callables._receiver import _unary_repeated_as
from ._branches import _OptionalGuard, _ResultGuard, _TraverseBranch
from ._result_accumulation import _result_map2, _result_loop, _ResultLoopCompatible, _FirstError
from ._selection import _Select, _Keep
from .protocols import _FamilyCallable
from fp.callables._views import _UnaryViewable
from .protocols import (_FamilyCarrier, _NativeFoldCompatible, _LiveAccumulator, _pure, Functor, Applicative, ApplicativeError, ErrorMapping, Monad, Traversable, Filterable, FunctorFilter, _Lifting, _Accumulate, _Present, _Item, _iterator,
                        _next_item, _start_as, _combine_as, _map_accumulate, _Append, _LinearLoopCompatible, _LinearProducerCompatible)


comptime _ListElement[V: Movable & Deinitable] = downcast[downcast[V, IterableOwned].IteratorOwnedType.Element, Movable & Deinitable]


# Carrier recognition has one owner. Effects declare their family through
# shared metadata; no effect implementation is imported into algebra. Guard
# iterable projection before inspecting its element. Bare values use fallback.
# A declaration is authoritative, including in generic wrappers; native
# recognition applies only to values without that declaration.
comptime _NativeFamily[V: Movable & Deinitable, Fallback: Functor = IdentityFamily]: Functor = (
    downcast[V, _FamilyCarrier].Family if conforms_to(V, _FamilyCarrier) else
    ResultFamily[downcast[V, _ResultType].Error] if conforms_to(V, _ResultType) else
    (ListFamily if V == List[_ListElement[V]] else
     OptionalFamily if V == Optional[_ListElement[V]] else Fallback)
    if conforms_to(V, IterableOwned) else Fallback
)

# Project Optional payloads only after native carrier recognition. Invalid
# carriers use an uninhabited placeholder; consumers still require the exact
# equality V == Optional[_OptionalElement[V]] before invoking any callback.
comptime _OptionalElement[V: Movable & Deinitable] = _ListElement[V] if _NativeFamily[V] == OptionalFamily else Never

# Recognition requires only Functor. Legacy Applicative entry points select
# their stronger capability here, retaining the existing Optional fallback.
comptime _InferredApplicative[V: Movable & Deinitable]: Applicative = (
    downcast[_NativeFamily[V, OptionalFamily], Applicative]
)


# Callable views preserve an explicitly selected policy before recognizing
# their output carrier. Pipeline and iterator entry points share this rule.
comptime _ViewFamily[C: _UnaryViewable, o: ImmOrigin, Fallback: Functor = IdentityFamily]: Functor = (
    downcast[C, _FamilyCallable]._Family if conforms_to(C, _FamilyCallable)
    else _NativeFamily[C._View[o].Out, Fallback]
)
comptime _ViewTarget[C: _UnaryViewable, o: ImmOrigin]: Applicative = downcast[_ViewFamily[C, o, OptionalFamily], Applicative]


struct IdentityFamily(Monad, Traversable):
    """The bare value as a carrier: every operation applies its callback once.

    `Reader[R]`, `State[S]` and `Writer[W]` are their transformers over it.
    """
    comptime _FoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _NativeFoldCompatible[V, P, F, K, K.Acc, False]
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _LinearLoopCompatible[V, F, K.Item, K.Error]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._LoopCompatible[V, F, _Append[F.Out]]
    comptime Element[V: Movable & Deinitable] = V
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = A
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = F.Out
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[F.Error, R.Error]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime TargetCompatible[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _OnceUnaryAvailable[F] and G.CarrierCompatible[F.Out]
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = K.Acc
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[F.Error, K.Error]

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Apply the callback to the value once.

        Parameters:
            V: The carrier's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The callback's result.

        Raises:
            The callback's error, unchanged.
        """
        comptime assert V == F.Arg, "map: callback argument must be the Identity value"
        return call_once(f^, rebind_var[F.Arg](value^))

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Return the value itself.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            The value.
        """
        return value^

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine the value with the one the thunk produces.

        Parameters:
            V: The left carrier's type.
            F: The combiner's type.
            R: The right operand's type: a thunk producing a carrier.

        Args:
            f: The combiner, consumed.
            left: The left carrier, consumed.
            right: The thunk producing the right carrier, consumed.

        Returns:
            The combiner's result.

        Raises:
            The combiner's or the thunk's error.
        """
        comptime assert V == F.First and R.Out == F.Second, "map2: operands must be the callback's Identity arguments"
        comptime E = Self.CombineError[V, F, R]
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, R.Error], "map2: incompatible native errors"
        var second = rebind_var[F.Second](_thunk_once_as[E](right^))
        return _binary_once_as[E](f^, rebind_var[F.First](left^), second^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Apply the callback to the value; its result is the next carrier.

        Parameters:
            V: The carrier's type.
            F: The callback's type, returning a carrier of the same family.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The callback's result.

        Raises:
            The callback's error, unchanged.
        """
        comptime assert V == F.Arg, "flat_map: callback argument must be the Identity value"
        return call_once(f^, rebind_var[F.Arg](value^))

    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        """Apply the callback to the one value; its `G` carrier is the result.

        Parameters:
            G: The callback's applicative family.
            V: The source carrier's type.
            F: The callback's type, returning a `G` carrier.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            The callback's `G` carrier.

        Raises:
            The callback's error, and any error `G` adds.
        """
        comptime assert V == F.Arg, "traverse: callback argument must be the Identity value"
        return call_once(f^, rebind_var[F.Arg](source^))

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        """One native loop: pull, call, combine while the accumulator is live."""
        comptime E = Self._LoopError[V, F, K]
        comptime assert _ErrorCompatible[E, K.Error]
        return _map_accumulate[V, F, K](f^, source^, _start_as[E, K]())


struct OptionalFamily(Monad, Traversable, Filterable, FunctorFilter, _Lifting):
    """The standard `Optional` as a carrier: an absent value skips callbacks and right operands."""
    comptime _FoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _NativeFoldCompatible[V, P, F, K, Optional[K.Acc], False]
    comptime CarrierCompatible[V: Movable & Deinitable] = V == Optional[Self.Element[V]] if conforms_to(V, IterableOwned) else False
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == Optional[F.Arg]
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.MapCompatible[V, F] and Self.CarrierCompatible[F.Out]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = V == Optional[F.First] and R.Out == Optional[F.Second]
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _LinearLoopCompatible[V, F, Optional[K.Item], K.Error]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[F.Out] & _LinearProducerCompatible[V, F, Never]
    comptime Element[V: Movable & Deinitable] = _ListElement[V]
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P.Failure
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Optional[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Optional[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Optional[F.Out]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[F.Error, R.Error]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime TargetCompatible[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _TraverseBranch[G, F, _Present[G.Element[F.Out]]].Compatible
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _OptionalGuard[G, _TraverseBranch[G, F, _Present[G.Element[F.Out]]]].Out
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CommonError[F.Error, G.MapError[F.Out, _Present[G.Element[F.Out]]]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Optional[K.Acc]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[F.Error, K.Error]
    comptime Lifted[V: Movable & Deinitable] = Optional[V]
    comptime LiftError[V: Movable & Deinitable] = Never

    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Optional[_ListElement[F.Out]]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.MapFiltered[V, F]:
        """Transform payloads once, retaining present results in source order.

        Parameters:
            V: The consumed source or carrier type.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            f: The callback, consumed; calls follow the operation's evaluation order.
            value: The source, consumed with its native origins; iterator sources are not restarted.

        Returns:
            The carrier of present transformed Optional payloads, in source order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime U = _ListElement[F.Out]
        comptime assert F.Out == Optional[U], "filter_map: Optional result required"
        return rebind_var[Self.MapFiltered[V, F]](Self.flat_map(f^, value^))

    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V
    ) raises P.Failure -> V:
        """Retain accepted Optional payloads, moving them unchanged.

        Parameters:
            V: The Optional carrier type.
            P: The borrowing Bool predicate type.

        Args:
            predicate: The predicate, consumed; it borrows each payload.
            value: The Optional, consumed; empty input skips the predicate.

        Returns:
            The same carrier type containing accepted original payloads.

        Raises:
            The predicate's exact error; failure destroys all owned values.
        """
        comptime T = Self.Element[V]
        comptime assert Self.CarrierCompatible[V] and P.Payload == T and P.Result == Bool
        return rebind_var[V](Self.filter_map(_Select[T, P](predicate^), value^))

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Apply the callback to a present value; an absent value passes through without a call.

        Parameters:
            V: The carrier's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The callback's result, present, or `None`.

        Raises:
            The callback's error, unchanged.
        """
        comptime assert Self.MapCompatible[V, F], "algebra: Optional carrier required"
        var present = rebind_var[Optional[F.Arg]](value^)
        if present:
            return Optional(call_once(f^, present.unsafe_take()))
        return Optional[F.Out]()

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Wrap the value as present.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            The present value.
        """
        return Optional(value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine two present values; an absent left value skips the thunk.

        Parameters:
            V: The left carrier's type.
            F: The combiner's type.
            R: The right operand's type: a thunk producing a carrier.

        Args:
            f: The combiner, consumed.
            left: The left carrier, consumed.
            right: The thunk producing the right carrier, consumed.

        Returns:
            The combination, present, or `None` when either side is absent.

        Raises:
            The combiner's or the thunk's error.
        """
        comptime assert Self.CombineCompatible[V, F, R], "map2: same family required"
        comptime E = Self.CombineError[V, F, R]
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, R.Error], "map2: incompatible native errors"
        var first = rebind_var[Optional[F.First]](left^)
        if not first:
            return Optional[F.Out]()
        var second = rebind_var[Optional[F.Second]](_thunk_once_as[E](right^))
        if not second:
            return Optional[F.Out]()
        return Optional(_binary_once_as[E](f^, first.unsafe_take(), second.unsafe_take()))

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Continue with the `Optional` the callback returns; an absent value skips the callback.

        Parameters:
            V: The carrier's type.
            F: The callback's type, returning a carrier of the same family.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The callback's `Optional`, or `None`.

        Raises:
            The callback's error, unchanged.
        """
        comptime assert Self.MapCompatible[V, F], "algebra: Optional carrier required"
        comptime assert Self.CarrierCompatible[F.Out], "flat_map: Optional callback required"
        var present = rebind_var[Optional[F.Arg]](value^)
        if present:
            return call_once(f^, present.unsafe_take())
        return rebind_var[F.Out](Optional[_ListElement[F.Out]]())

    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        """Call the callback on a present value and keep its payload present in `G`; an absent value gives `G.pure(None)`.

        Parameters:
            G: The callback's applicative family.
            V: The source carrier's type.
            F: The callback's type, returning a `G` carrier.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            `G`'s carrier of the `Optional`.

        Raises:
            The callback's error, and any error `G` adds.
        """
        comptime assert Self.TraverseCompatible[V, F], "traverse: Optional source required"
        comptime B = G.Element[F.Out]
        comptime Step = _TraverseBranch[G, F, _Present[B]]
        return _OptionalGuard[G, Step](Step(f^, _Present[B]())).call_once(rebind_var[Optional[F.Arg]](source^))

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        """One native loop; the first absent element stops pulls and calls."""
        comptime E = Self._LoopError[V, F, K]
        comptime assert RepeatableUnary[F], "traverse: the callback must be repeatable"
        comptime assert _Item[V] == F.Arg, "traverse: callback argument must be the source element"
        comptime assert F.Out == Optional[K.Item], "traverse: callback must return an Optional of the accumulated payload"
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, K.Error]
        var iterator = _iterator(source^)
        var acc = _start_as[E, K]()
        while K.live(acc):
            var item = _next_item[V](iterator)
            if not item:
                break
            var produced = rebind_var[Optional[K.Item]](_unary_repeated_as[E](f, rebind_var[F.Arg](item.unsafe_take())))
            if not produced:
                return Optional[K.Acc]()
            acc = _combine_as[E, K](acc^, produced.unsafe_take())
        return Optional(acc^)

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) -> Self.Lifted[V]:
        """Wrap a value as present, for a layer over `OptionalFamily`.

        Parameters:
            V: The base value's type.

        Args:
            value: The value, consumed.

        Returns:
            The present value.
        """
        return Optional(value^)


@fieldwise_init
struct _OkOf[B: Movable & Deinitable, E: Movable & Deinitable](Unary, Copyable, Defaultable):
    comptime Arg = Self.B
    comptime Out = Result[Self.B, Self.E]
    def call(self, var arg: Self.Arg) -> Self.Out:
        return Result[Self.B, Self.E](Ok(arg^))


struct ResultFamily[E: Movable & Deinitable](Monad, ApplicativeError, ErrorMapping, Traversable, _Lifting):
    """`Result[A, E]` as a carrier for a fixed stored error type `E`: a stored error skips callbacks and stays data.

    Its operations are the `Result` methods. A native error a callback raises
    propagates as a native error; it never becomes the stored `Err`.

    Parameters:
        E: The stored error type.
    """
    comptime _FoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _NativeFoldCompatible[V, P, F, K, Result[K.Acc, Self.E], False]
    comptime Error = Self.E
    comptime Failure = Self.E
    # Keep exact nominal equality as the proof generic forwarders provide.
    # A separate conforms_to premise is redundant and Mojo 1.2 cannot always
    # derive it from that equality before selecting a generic overload.
    comptime CarrierCompatible[V: Movable & Deinitable] = Self._ErrorCarrier[V]
    comptime _ErrorCarrier[V: Movable & Deinitable] = V == Result[Self.Element[V], Self.E]
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = Self._ErrorCarrier[V]
    comptime DefaultErrorTarget[A: Movable & Deinitable, U: Movable & Deinitable] = ResultFamily[U]
    # These total type equalities use eager OR: short-circuit conditionals hide
    # equal-X and pure/X evidence during generic native overload selection.
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = (
        Target == ResultFamily[G.Out] and _CommonErrorCompatible[F.Error,G.Error]
    )
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Result[F.Out,G.Out]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = _CommonError[F.Error,G.Error]
    # These signature predicates are the Result family's single admission
    # contract. Body assertions run after origins may have been erased.
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._ErrorCarrier[V]
    """Require the selected Result error type and its origins before mapping."""
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = (
        Self._ErrorCarrier[V] and Self._ErrorCarrier[R.Out] and
        Self.Element[V] == F.First and Self.Element[R.Out] == F.Second
    )
    """Require both Results and both callback inputs to match the selected family."""
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _ResultLoopCompatible[V, F, K, Self.E]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._ErrorCarrier[F.Out] & _LinearProducerCompatible[V, F, Never]
    """Require each produced Result to retain the selected stored error and origins."""
    comptime Failed[A: Movable & Deinitable] = Result[A, Self.E]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Result[Self.Element[V], Self.E]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = H.Error
    comptime Element[V: Movable & Deinitable] = downcast[V, _ResultType].Value
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Result[F.Out, Self.E]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Result[A, Self.E]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Result[F.Out, Self.E]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[F.Error, R.Error]
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = (
        (Self.MapCompatible[V, F] and Self._ErrorCarrier[F.Out] and Self.Element[V] == F.Arg)
        if conforms_to(F.Out, _ResultType) else False
    )
    """Require the callback to return a Result with the same stored error and origins."""
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime TargetCompatible[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _TraverseBranch[G, F, _OkOf[G.Element[F.Out], Self.E]].Compatible
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _ResultGuard[G, Self.E, _TraverseBranch[G, F, _OkOf[G.Element[F.Out], Self.E]]].Out
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CommonError[F.Error, G.MapError[F.Out, _OkOf[G.Element[F.Out], Self.E]]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Result[K.Acc, Self.E]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[F.Error, K.Error]
    comptime Lifted[V: Movable & Deinitable] = Result[V, Self.E]
    comptime LiftError[V: Movable & Deinitable] = Never

    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](
        var on_ok: F, var on_err: G, var source: V
    ) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        """Transform the original branch through Result's existing owned fold.

        Parameters:
            Target: The admitted ResultFamily with the transformed error type.
            V: The source Result type.
            F: The consuming success callback type.
            G: The consuming stored-error callback type.

        Args:
            on_ok: The callback selected by an original success.
            on_err: The callback selected by an original stored error.
            source: The consumed Result; exactly one callback runs.

        Returns:
            The original Result constructor with its transformed payload.

        Raises:
            The selected callback's exact native error.
        """
        comptime assert V == Result[F.Arg,Self.E] and G.Arg == Self.E
        comptime assert F.Error == G.Error or F.Error == Never or G.Error == Never
        return rebind_var[Result[F.Arg,Self.E]](source^).map_both(on_ok^,on_err^)

    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) -> Self.Failed[A]:
        """Construct Err with the exact stored error type and success type A.

        Parameters:
            A: The absent success payload type.

        Args:
            error: The stored error, consumed with its exact type and origins.

        Returns:
            A native Err carrying the supplied error.
        """
        return Result[A, Self.E](Err(error^))

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V
    ) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        """Recover through Result's canonical owned transformation.

        Parameters:
            V: The source Result type.
            H: The handler consuming the stored error and returning the same
                Result success and error types.

        Args:
            handler: The handler, consumed and skipped on success.
            source: The Result, consumed.

        Returns:
            The original success or the handler's Result.

        Raises:
            The exact native error raised by the handler.
        """
        comptime assert Self._Handles[V, H], "or_else: handler must retain success and stored-error types"
        return rebind_var[Self.Handled[V, H]](rebind_var[Result[Self.Element[V], Self.E]](source^).or_else(handler^))

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Apply the callback to the success value; a stored error passes through without a call.

        Parameters:
            V: The carrier's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            `Ok` of the callback's result, or the stored `Err`.

        Raises:
            The callback's error, unchanged.
        """
        comptime assert V == Result[F.Arg, Self.E], "algebra: Result family/error mismatch"
        return rebind_var[Result[F.Arg, Self.E]](value^).map(f^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Wrap the value as `Ok`.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            `Ok(value)`.
        """
        return Result[A, Self.E](Ok(value^))

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine two success values; a stored error on the left skips the thunk.

        Parameters:
            V: The left carrier's type.
            F: The combiner's type.
            R: The right operand's type: a thunk producing a carrier.

        Args:
            f: The combiner, consumed.
            left: The left carrier, consumed.
            right: The thunk producing the right carrier, consumed.

        Returns:
            `Ok` of the combination, or the first stored `Err`.

        Raises:
            The combiner's or the thunk's error.
        """
        comptime assert V == Result[F.First, Self.E] and R.Out == Result[F.Second, Self.E], "map2: same family required"
        return _result_map2[Self.E, X=Self.CombineError[V, F, R]](f^, rebind_var[Result[F.First, Self.E]](left^), right^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Continue with the `Result` the callback returns; a stored error skips the callback.

        Parameters:
            V: The carrier's type.
            F: The callback's type, returning a carrier of the same family.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The callback's `Result`, or the stored `Err`.

        Raises:
            The callback's error, unchanged.
        """
        comptime assert V == Result[F.Arg, Self.E], "algebra: Result family/error mismatch"
        comptime assert F.Out == Result[Self.Element[F.Out], Self.E], "flat_map: callback must return the same Result family"
        return rebind_var[Result[F.Arg, Self.E]](value^).flat_map(f^)

    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        """Call the callback on the success value and wrap its payload as `Ok` in `G`; a stored error gives `G.pure` of it.

        Parameters:
            G: The callback's applicative family.
            V: The source carrier's type.
            F: The callback's type, returning a `G` carrier.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            `G`'s carrier of the `Result`.

        Raises:
            The callback's error, and any error `G` adds.
        """
        comptime assert V == Result[F.Arg, Self.E], "traverse: Result source required"
        comptime B = G.Element[F.Out]
        comptime Step = _TraverseBranch[G, F, _OkOf[B, Self.E]]
        return _ResultGuard[G, Self.E, Step](Step(f^, _OkOf[B, Self.E]())).call_once(rebind_var[Result[F.Arg, Self.E]](source^))

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        return _result_loop[V, F, K, _FirstError[Self.E], Self._LoopError[V, F, K]](f^, source^)

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) -> Self.Lifted[V]:
        """Wrap a value as `Ok`, for a layer over `ResultFamily`.

        Parameters:
            V: The base value's type.

        Args:
            value: The value, consumed.

        Returns:
            `Ok(value)`.
        """
        return _pure[Self](value^)


struct ListFamily(Monad, Traversable, Filterable, FunctorFilter):
    """The standard `List` as a carrier: operations run left to right, and combination is Cartesian.

    Callbacks run once per element, so they must be repeatable: a shared or
    exclusive receiver.
    """
    # Traversal also accepts an existing iterator, without restarting it.
    comptime _FoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _NativeFoldCompatible[V, P, F, K, List[K.Acc], True]
    comptime CarrierCompatible[V: Movable & Deinitable] = V == List[Self.Element[V]] if conforms_to(V, IterableOwned) else False
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == List[F.Arg] and RepeatableUnary[F]
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.MapCompatible[V, F] and Self.CarrierCompatible[F.Out]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = (
        V == List[F.First] and R.Out == List[F.Second] and RepeatableBinary[F] and
        conforms_to(F.First, Copyable) and conforms_to(F.Second, Copyable) and
        _OnceThunkAvailable[R] and _CommonErrorCompatible[F.Error,R.Error]
    )
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = (
        F.Out == List[K.Item] and RepeatableUnary[F] and
        conforms_to(K.Acc, Copyable) and conforms_to(K.Item, Copyable) and
        _CommonErrorCompatible[F.Error, K.Error]
    )
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._LoopCompatible[V, F, _Append[Self.Element[F.Out]]] if Self.CarrierCompatible[F.Out] else False
    comptime TraverseCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Element[V] == F.Arg if conforms_to(V, Iterator) or conforms_to(V, IterableOwned) else False
    comptime Element[V: Movable & Deinitable] = _Item[V]
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P.Failure
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = List[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = List[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = List[F.Out]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[F.Error, R.Error]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = G.Collected[V, F]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = G.CollectError[V, F]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = List[K.Acc]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[F.Error, K.Error]

    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = List[_ListElement[F.Out]]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.MapFiltered[V, F]:
        """Transform payloads once, retaining present results in source order.

        Parameters:
            V: The consumed source or carrier type.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            f: The callback, consumed; calls follow the operation's evaluation order.
            value: The source, consumed with its native origins; iterator sources are not restarted.

        Returns:
            The carrier of present transformed Optional payloads, in source order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime U = _ListElement[F.Out]
        comptime assert F.Out == Optional[U], "filter_map: Optional result required"
        comptime assert Self.MapCompatible[V, F], "filter_map: List carrier and repeatable callback required"
        return _map_accumulate[V, F, _Keep[_Append[U]], F.Error](f^, value^, List[U]())

    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V
    ) raises P.Failure -> V:
        """Retain accepted List payloads, moving them unchanged.

        Parameters:
            V: The List carrier type.
            P: The borrowing Bool predicate type.

        Args:
            predicate: The predicate, consumed; it borrows each payload.
            value: The List, consumed; empty input skips the predicate.

        Returns:
            The same carrier type containing accepted original payloads.

        Raises:
            The predicate's exact error; failure destroys all owned values.
        """
        comptime T = Self.Element[V]
        comptime assert Self.CarrierCompatible[V] and P.Payload == T and P.Result == Bool
        return rebind_var[V](Self.filter_map(_Select[T, P](predicate^), value^))

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Apply the callback to each element, left to right.

        Parameters:
            V: The carrier's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The list of results.

        Raises:
            The callback's error, unchanged.
        """
        comptime assert RepeatableUnary[F], "List callbacks must be repeatable"
        comptime assert Self.MapCompatible[V, F], "algebra: List carrier required"
        return _map_accumulate[List[F.Arg], F, _Append[F.Out], F.Error](
            f^, rebind_var[List[F.Arg]](value^), List[F.Out]())

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """A list of one element.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            The one-element list.
        """
        var result = List[A]()
        result.append(value^)
        return result^

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine every pair of elements, in left-major order.

        The thunk runs once, and not at all for an empty left list. Elements are
        copied into every pair, so both element types must be `Copyable`, and the
        combiner must be repeatable.

        Parameters:
            V: The left carrier's type.
            F: The combiner's type.
            R: The right operand's type: a thunk producing a carrier.

        Args:
            f: The combiner, consumed.
            left: The left carrier, consumed.
            right: The thunk producing the right carrier, consumed.

        Returns:
            The list of combinations: for `[a, b]` and `[x, y]`, `(a, x)`, `(a, y)`, `(b, x)`, `(b, y)`.

        Raises:
            The combiner's or the thunk's error.
        """
        comptime assert RepeatableBinary[F], "List combination requires a repeatable callback"
        comptime assert conforms_to(F.First, Copyable) and conforms_to(F.Second, Copyable), "List combination copies each element into every pair"
        comptime E = Self.CombineError[V, F, R]
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, R.Error], "map2: incompatible native errors"
        # Primitive callers retain specific diagnostics before aggregate admission.
        comptime assert Self.CombineCompatible[V, F, R], "map2: same family required"
        comptime L = downcast[F.First, Copyable & Deinitable]
        comptime S = downcast[F.Second, Copyable & Deinitable]
        var firsts = rebind_var[List[F.First]](left^)
        var result = List[F.Out]()
        if len(firsts) == 0:
            return result^
        var seconds = rebind_var[List[F.Second]](_thunk_once_as[E](right^))
        for i in range(len(firsts)):
            for j in range(len(seconds)):
                var first = rebind_var[F.First](rebind[L](firsts[i]).copy())
                var second = rebind_var[F.Second](rebind[S](seconds[j]).copy())
                result.append(_binary_repeated_as[E](f, first^, second^))
        return result^

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Concatenate the lists the callback returns for each element, left to right.

        Parameters:
            V: The carrier's type.
            F: The callback's type, returning a carrier of the same family.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The concatenated list.

        Raises:
            The callback's error, unchanged.
        """
        comptime U = _ListElement[F.Out]
        comptime assert RepeatableUnary[F], "List callbacks must be repeatable"
        comptime assert Self.MapCompatible[V, F], "algebra: List carrier required"
        comptime assert Self.CarrierCompatible[F.Out], "flat_map: List callback required"
        var source = iter(rebind_var[List[F.Arg]](value^))
        var result = List[U]()
        while True:
            var item = _next_optional[F.Arg](source)
            if not item:
                return rebind_var[F.Out](result^)
            result.extend(rebind_var[List[U]](call_repeated(f, item.unsafe_take())))

    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        """Call the callback on each element and gather the payloads with `G.collect`.

        The first failed or absent result stops callback calls and source pulls.
        Any owned iterable or iterator can be the source.

        Parameters:
            G: The callback's applicative family.
            V: The source carrier's type.
            F: The callback's type, returning a `G` carrier.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            `G`'s carrier of the list of payloads.

        Raises:
            The callback's error, and any error `G` adds.
        """
        # Any owned iterable or iterator source; collection admits its items.
        return G.collect(f^, source^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        """One loop over branches: before each pull, stop unless a branch is
        live; call the producer once per element; each live branch combines
        with every produced element in order, and inactive branches carry
        unchanged. With the append policy this is Cartesian combination."""
        comptime X = K.Item
        comptime E = Self._LoopError[V, F, K]
        comptime assert RepeatableUnary[F], "traverse: the callback must be repeatable"
        comptime assert _Item[V] == F.Arg, "traverse: callback argument must be the source element"
        comptime assert F.Out == List[X], "traverse: callback must return a List of the accumulated payload"
        comptime assert conforms_to(K.Acc, Copyable) and conforms_to(X, Copyable), "List traversal copies accumulators and elements into every branch"
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, K.Error]
        comptime A = downcast[K.Acc, Copyable & Deinitable]
        comptime C = downcast[X, Copyable & Deinitable]
        var iterator = _iterator(source^)
        var branches = List[K.Acc]()
        branches.append(_start_as[E, K]())
        while True:
            var live = False
            for index in range(len(branches)):
                if K.live(branches[index]):
                    live = True
                    break
            if not live:
                return branches^
            var item = _next_item[V](iterator)
            if not item:
                return branches^
            var produced = rebind_var[List[X]](_unary_repeated_as[E](f, rebind_var[F.Arg](item.unsafe_take())))
            var previous = iter(branches^)
            branches = List[K.Acc]()
            while True:
                var branch = _next_optional[K.Acc](previous)
                if not branch:
                    break
                var acc = branch.unsafe_take()
                if not K.live(acc):
                    branches.append(acc^)
                    continue
                for index in range(len(produced)):
                    var copy = rebind_var[K.Acc](rebind[A](acc).copy())
                    var element = rebind_var[X](rebind[C](produced[index]).copy())
                    branches.append(_combine_as[E, K](copy^, element^))
