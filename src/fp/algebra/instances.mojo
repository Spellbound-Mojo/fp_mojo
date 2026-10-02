"""Static instances for native values; container storage is never replaced.

Identity is the bare value; Optional, Result and List keep their own storage.
Result transformations use the owned transformation of the Result methods.
"""
from std.builtin.rebind import rebind_var, rebind, downcast
from std.iter import IterableOwned
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, Unary
from fp.callables.invoke import RepeatableUnary, RepeatableBinary, call_once, call_repeated
from fp.callables._receiver import _unary_once_as, _binary_once_as, _binary_repeated_as, _thunk_once_as
from fp.data._result import Result, Ok, Err, _ResultType, _transform_result_owned
from fp.iteration._advance import _next_optional
from fp.iteration._terminal import _append
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from fp.callables._receiver import _unary_repeated_as
from .protocols import (Applicative, Monad, Traversable, _Lifting, _Accumulate, _Present, _Item, _iterator,
                        _next_item, _start_as, _combine_as)


comptime _ListElement[V: Movable & Deinitable] = downcast[downcast[V, IterableOwned].IteratorOwnedType.Element, Movable & Deinitable]


struct IdentityFamily(Monad, Traversable):
    """The bare value as a carrier: every operation applies its callback once.

    `Reader[R]`, `State[S]` and `Writer[W]` are their transformers over it.
    """
    comptime Element[V: Movable & Deinitable] = V
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = A
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = F.Out
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[F.Error, R.Error]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
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
        comptime assert RepeatableUnary[F], "traverse: the callback must be repeatable"
        comptime assert _Item[V] == F.Arg, "traverse: callback argument must be the source element"
        comptime assert F.Out == K.Item, "traverse: the accumulator must receive the callback's payload"
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, K.Error]
        var iterator = _iterator(source^)
        var acc = _start_as[E, K]()
        while K.live(acc):
            var item = _next_item[V](iterator)
            if not item:
                break
            var produced = _unary_repeated_as[E](f, rebind_var[F.Arg](item.unsafe_take()))
            acc = _combine_as[E, K](acc^, rebind_var[K.Item](produced^))
        return acc^


struct OptionalFamily(Monad, Traversable, _Lifting):
    """The standard `Optional` as a carrier: an absent value skips callbacks and right operands."""
    comptime Element[V: Movable & Deinitable] = _ListElement[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Optional[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Optional[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Optional[F.Out]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[F.Error, R.Error]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = G.Mapped[F.Out, _Present[G.Element[F.Out]]]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CommonError[F.Error, G.MapError[F.Out, _Present[G.Element[F.Out]]]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Optional[K.Acc]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[F.Error, K.Error]
    comptime Lifted[V: Movable & Deinitable] = Optional[V]
    comptime LiftError[V: Movable & Deinitable] = Never

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
        comptime assert V == Optional[F.Arg], "algebra: Optional carrier required"
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
        comptime assert V == Optional[F.First] and R.Out == Optional[F.Second], "map2: same family required"
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
        comptime assert V == Optional[F.Arg], "algebra: Optional carrier required"
        comptime assert F.Out == Optional[_ListElement[F.Out]], "flat_map: Optional callback required"
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
        comptime B = G.Element[F.Out]
        comptime E = Self.TraverseError[G, V, F]
        comptime assert V == Optional[F.Arg], "traverse: Optional source required"
        comptime assert G.Pure[Optional[B]] == Self.Traversed[G, V, F], "traverse: target must represent absence and presence with one type"
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, G.MapError[F.Out, _Present[B]]]
        var present = rebind_var[Optional[F.Arg]](source^)
        if not present:
            return rebind_var[Self.Traversed[G, V, F]](G.pure(Optional[B]()))
        var produced = _unary_once_as[E](f^, present.unsafe_take())
        try:
            return G.map(_Present[B](), produced^)
        except error:
            _propagate_error[E](error^)

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


@fieldwise_init
struct _ResultRight[F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, S: Movable & Deinitable](Movable):
    """Context for the left success: produce the right operand, then combine."""
    var f: Self.F
    var right: Self.R
    comptime Error = _CommonError[Self.F.Error, Self.R.Error]
    def apply(deinit self, var first: Self.F.First) raises Self.Error -> Result[Self.F.Out, Self.S]:
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.R.Error]
        var second = rebind_var[Result[Self.F.Second, Self.S]](_thunk_once_as[Self.Error](self.right^))
        try:
            return _transform_result_owned[Self.F.Second, Self.S, Self.F.Out, Self.S, Self.F.Error, True, True,
                Self.F.Second, Self.F.Out, _ResultLeft[Self.F, Self.S], _result_combine[Self.F, Self.S]](
                second^, _ResultLeft[Self.F, Self.S](self.f^, first^))
        except error:
            _propagate_error[Self.Error](error^)


@fieldwise_init
struct _ResultLeft[F: BinaryContract & Movable & Deinitable, S: Movable & Deinitable](Movable):
    """Context for the right success: the callback and the left payload."""
    var f: Self.F
    var first: Self.F.First
    def apply(deinit self, var second: Self.F.Second) raises Self.F.Error -> Self.F.Out:
        return call_once(self.f^, self.first^, second^)


def _result_right[F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, S: Movable & Deinitable](
    var first: F.First, var context: _ResultRight[F, R, S]
) raises _CommonError[F.Error, R.Error] capturing -> Result[F.Out, S]:
    return context^.apply(first^)


def _result_combine[F: BinaryContract & Movable & Deinitable, S: Movable & Deinitable](
    var second: F.Second, var context: _ResultLeft[F, S]
) raises F.Error capturing -> F.Out:
    return context^.apply(second^)


struct ResultFamily[E: Movable & Deinitable](Monad, Traversable, _Lifting):
    """`Result[A, E]` as a carrier for a fixed stored error type `E`: a stored error skips callbacks and stays data.

    Its operations are the `Result` methods. A native error a callback raises
    propagates as a native error; it never becomes the stored `Err`.

    Parameters:
        E: The stored error type.
    """
    comptime Error = Self.E
    comptime Element[V: Movable & Deinitable] = downcast[V, _ResultType].Value
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Result[F.Out, Self.E]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Pure[A: Movable & Deinitable] = Result[A, Self.E]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Result[F.Out, Self.E]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _CommonError[F.Error, R.Error]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = G.Mapped[F.Out, _OkOf[G.Element[F.Out], Self.E]]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CommonError[F.Error, G.MapError[F.Out, _OkOf[G.Element[F.Out], Self.E]]]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Result[K.Acc, Self.E]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _CommonError[F.Error, K.Error]
    comptime Lifted[V: Movable & Deinitable] = Result[V, Self.E]
    comptime LiftError[V: Movable & Deinitable] = Never

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
        comptime E = Self.CombineError[V, F, R]
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, R.Error], "map2: incompatible native errors"
        return _transform_result_owned[F.First, Self.E, F.Out, Self.E, E, True, False, F.First, Result[F.Out, Self.E],
            _ResultRight[F, R, Self.E], _result_right[F, R, Self.E]](
            rebind_var[Result[F.First, Self.E]](left^), _ResultRight[F, R, Self.E](f^, right^))

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
        comptime B = G.Element[F.Out]
        comptime X = Self.TraverseError[G, V, F]
        comptime assert V == Result[F.Arg, Self.E], "traverse: Result source required"
        comptime assert G.Pure[Result[B, Self.E]] == Self.Traversed[G, V, F], "traverse: target must represent both Result cases with one type"
        var value = rebind_var[Result[F.Arg, Self.E]](source^)
        if value.is_err():
            var stored = value^._take_err()
            return rebind_var[Self.Traversed[G, V, F]](G.pure(Result[B, Self.E](Err(rebind_var[Self.E](stored^)))))
        comptime assert _ErrorCompatible[X, F.Error] and _ErrorCompatible[X, G.MapError[F.Out, _OkOf[B, Self.E]]]
        var produced = _unary_once_as[X](f^, rebind_var[F.Arg](value^._take_ok()))
        try:
            return G.map(_OkOf[B, Self.E](), produced^)
        except error:
            _propagate_error[X](error^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        """One native loop; the first stored error stops pulls and calls."""
        comptime B = K.Item
        comptime X = Self._LoopError[V, F, K]
        comptime assert RepeatableUnary[F], "traverse: the callback must be repeatable"
        comptime assert _Item[V] == F.Arg, "traverse: callback argument must be the source element"
        comptime assert F.Out == Result[B, Self.E], "traverse: callback must return the same Result family"
        comptime assert _ErrorCompatible[X, F.Error] and _ErrorCompatible[X, K.Error]
        var iterator = _iterator(source^)
        var acc = _start_as[X, K]()
        while K.live(acc):
            var item = _next_item[V](iterator)
            if not item:
                break
            var produced = rebind_var[Result[B, Self.E]](_unary_repeated_as[X](f, rebind_var[F.Arg](item.unsafe_take())))
            if produced.is_err():
                return Result[K.Acc, Self.E](Err(rebind_var[Self.E](produced^._take_err())))
            acc = _combine_as[X, K](acc^, rebind_var[B](produced^._take_ok()))
        return Result[K.Acc, Self.E](Ok(acc^))

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
        return Self.pure(value^)


struct ListFamily(Monad, Traversable):
    """The standard `List` as a carrier: operations run left to right, and combination is Cartesian.

    Callbacks run once per element, so they must be repeatable: a shared or
    exclusive receiver.
    """
    comptime Element[V: Movable & Deinitable] = _ListElement[V]
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
        comptime assert V == List[F.Arg], "algebra: List carrier required"
        comptime assert RepeatableUnary[F], "List callbacks must be repeatable"
        var source = iter(rebind_var[List[F.Arg]](value^))
        var result = List[F.Out]()
        while True:
            var item = _next_optional[F.Arg](source)
            if not item:
                return result^
            result = _append[F.Out](result^, call_repeated(f, item.unsafe_take()), Tuple())

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
        comptime assert V == List[F.First] and R.Out == List[F.Second], "map2: same family required"
        comptime assert RepeatableBinary[F], "List combination requires a repeatable callback"
        comptime assert conforms_to(F.First, Copyable) and conforms_to(F.Second, Copyable), "List combination copies each element into every pair"
        comptime E = Self.CombineError[V, F, R]
        comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, R.Error], "map2: incompatible native errors"
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
        comptime assert V == List[F.Arg], "algebra: List carrier required"
        comptime assert F.Out == List[U], "flat_map: List callback required"
        comptime assert RepeatableUnary[F], "List callbacks must be repeatable"
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
