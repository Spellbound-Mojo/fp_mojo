"""Static algebra dictionaries: result types are aliases, behavior is in methods.

An instance's associated types name only its own parameters and the types of
the values and callbacks it receives, so naming an instance evaluates no other
operation. Operations are static methods; the free functions in `operations`
forward to them. Callbacks use the fixed-arity protocols of `fp.callables`.
"""
from std.builtin.rebind import rebind_var, downcast
from std.iter import IterableOwned, Iterator
from std.builtin.rebind import rebind
from fp.callables.protocols import (UnaryContract, BinaryContract, ThunkContract,
                                    Unary, Binary, OnceUnary, MutableUnary, OnceThunk)
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _unary_repeated_as
from fp.iteration._advance import _next_optional
from fp.iteration._terminal import _append
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error


trait Functor:
    """A carrier family whose payload can be transformed without changing its context: `map`."""
    comptime Element[V: Movable & Deinitable]: Movable & Deinitable
    """The payload type of a carrier `V` of this family."""
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `map` returns for a carrier `V` and a callback `F`."""
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The error `map` raises for a carrier `V` and a callback `F`."""
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Transform the payload of `value` with `f`, keeping its context.

        Parameters:
            V: The carrier's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The carrier of the callback's results.

        Raises:
            The callback's error, and any error the family adds.
        """
        ...


trait Applicative(Functor):
    """A `Functor` that can introduce a payload (`pure`) and combine independent computations (`map2_lazy`).

    `collect` gathers every payload a callback produces over a source into a
    `List`, and list traversal into this family uses it. It is the private
    `_loop` with an append rule: one pull loop whose accumulation rule decides
    how payloads combine and when the accumulator stops being live. The default
    `_loop` runs over `pure`, `map` and `map2_lazy` and stops pulling once the
    accumulator has failed. It requires an accumulator type that stays the same
    across steps; a family whose combination changes type overrides the private
    `_Looped`, `_LoopError` and `_loop` with its own single loop.
    """
    comptime Pure[A: Movable & Deinitable]: Movable & Deinitable
    """The carrier `pure` returns for a payload `A`."""
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `map2_lazy` returns."""
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]: Movable & Deinitable
    """The error `map2_lazy` raises."""
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate]: Movable & Deinitable = Self.Pure[K.Acc]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate]: Movable & Deinitable = _CommonError[
        K.Error, Self.CombineError[Self.Pure[K.Acc], _FoldShape[K],
                                   _PullShape[Self.Mapped[F.Out, _Present[K.Item]], F.Error, Self.MapError[F.Out, _Present[K.Item]]]]]
    comptime Collected[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable = Self._Looped[V, F, _Append[Self.Element[F.Out]]]
    """The carrier `collect` returns: this family's carrier of a `List`."""
    comptime CollectError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable = Self._LoopError[V, F, _Append[Self.Element[F.Out]]]
    """The error `collect` raises."""
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Introduce a payload in the family's neutral context.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            The carrier holding `value`.
        """
        ...
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine the payloads of `left` and of the carrier `right` produces with `f`.

        `right` runs zero or one times per combination: a left carrier with no
        payload, such as an absent `Optional`, skips it.

        Parameters:
            V: The left carrier's type.
            F: The combiner's type, taking the two payloads.
            R: The right operand's type: a thunk producing a carrier of this family.

        Args:
            f: The combiner, consumed.
            left: The left carrier, consumed.
            right: The thunk producing the right carrier, consumed.

        Returns:
            The carrier of the combined payloads.

        Raises:
            The combiner's or the thunk's error.
        """
        ...
    @staticmethod
    def collect[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.CollectError[V, F] -> Self.Collected[V, F]:
        """Call `f` on each element of `source` and gather the payloads into one carrier of a `List`.

        The first failed or absent result stops both callback calls and source
        pulls. This is list traversal into this family.

        Parameters:
            V: The source's type: an iterator or an owned iterable.
            F: The callback's type, returning a carrier of this family; it must
                be repeatable.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            The carrier of the payloads, in source order.

        Raises:
            The callback's error, and any error the family's combination raises.
        """
        comptime K = _Append[Self.Element[F.Out]]
        comptime assert _ErrorCompatible[Self.CollectError[V, F], Self._LoopError[V, F, K]]
        try:
            return rebind_var[Self.Collected[V, F]](Self._loop[V, F, K](f^, source^))
        except error:
            _propagate_error[Self.CollectError[V, F]](error^)
    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        comptime X = K.Item
        comptime Acc = Self.Pure[K.Acc]
        comptime Shape = _PullShape[Self.Mapped[F.Out, _Present[X]], F.Error, Self.MapError[F.Out, _Present[X]]]
        comptime E = Self._LoopError[V, F, K]
        comptime assert RepeatableUnary[F], "traverse: the callback must be repeatable"
        comptime assert _Item[V] == F.Arg, "traverse: callback argument must be the source element"
        comptime assert Self.Element[F.Out] == X, "traverse: the accumulator must receive the callback's payload"
        comptime assert Self.Pure[Optional[X]] == Shape.Out, "traverse: target must represent a pulled element and exhaustion with one type"
        comptime assert Self._Looped[V, F, K] == Acc, "traverse: this target overrides _loop"
        comptime assert _ErrorCompatible[E, K.Error]
        var iterator = _iterator(source^)
        var start = _start_as[E, K]()
        var live = K.live(start)
        var result = Self.pure(start^)
        while live:
            # The fold records whether a branch is still live. A skipped right
            # operand leaves `ended` set: once the accumulator has failed or
            # the source is exhausted, the source is never pulled again.
            live = False
            var ended = True
            var fold = _Fold[K, origin_of(live)](Pointer(to=live))
            var pull = _Pull[Self, V, F, X, origin_of(iterator), origin_of(f), origin_of(ended)](
                Pointer(to=iterator), Pointer(to=f), Pointer(to=ended))
            comptime Folding = type_of(fold)
            comptime Step = type_of(pull)
            comptime assert Self.Combined[Acc, Folding, Step] == Acc, "traverse: target accumulator type must not change between steps"
            comptime assert Self.CombineError[Acc, Folding, Step] == Self.CombineError[Acc, _FoldShape[K], Shape], "traverse: target combination error must depend only on the operand's result and error"
            try:
                result = rebind_var[Acc](Self.map2_lazy(fold^, result^, pull^))
            except error:
                comptime assert _ErrorCompatible[E, type_of(error)]
                _propagate_error[E](error^)
            if ended:
                break
        return rebind_var[Self._Looped[V, F, K]](result^)


trait Monad(Applicative):
    """An `Applicative` whose callback chooses the next computation from the current payload: `flat_map`.

    A deferred family that is a transformer base also overrides the private
    `_Joined[L, R]`, `_join_left` and `_join_right`: one carrier type holding
    either of two computations of this family, which a transformer step that
    returns one of two computations uses. The default serves eager families,
    whose carriers of one payload already share one type.
    """
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `flat_map` returns: the callback's own carrier type."""
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The error `flat_map` raises."""
    comptime _Joined[L: Movable & Deinitable, R: Movable & Deinitable]: Movable & Deinitable = L
    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Continue with the carrier `f` returns for the payload of `value`.

        Parameters:
            V: The carrier's type.
            F: The callback's type, returning a carrier of this family.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The carrier the callback returned, or the original context when
            there is no payload.

        Raises:
            The callback's error.
        """
        ...
    @staticmethod
    def _join_left[L: Movable & Deinitable, R: Movable & Deinitable](var value: L) -> Self._Joined[L, R]:
        comptime assert L == R, "choice: branches of an eager family must have one carrier type"
        return rebind_var[Self._Joined[L, R]](value^)
    @staticmethod
    def _join_right[L: Movable & Deinitable, R: Movable & Deinitable](var value: R) -> Self._Joined[L, R]:
        comptime assert L == R, "choice: branches of an eager family must have one carrier type"
        return rebind_var[Self._Joined[L, R]](value^)


trait Traversable(Functor):
    """A source shape whose elements can be visited with an effectful callback, keeping the shape: `traverse`."""
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `traverse` returns: `G`'s carrier of this shape."""
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The error `traverse` raises."""
    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        """Call `f` on each element of `source`, in order, and gather the results into one `G` carrier of the same shape.

        Parameters:
            G: The applicative family the callback returns.
            V: The source's type, of this shape.
            F: The callback's type, returning a `G` carrier.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            `G`'s carrier of the results, in source shape and order.

        Raises:
            The callback's error, and any error `G` adds.
        """
        ...


trait _Lifting:
    """Embed a base carrier as a carrier of this family."""
    comptime Lifted[V: Movable & Deinitable]: Movable & Deinitable
    comptime LiftError[V: Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) raises Self.LiftError[V] -> Self.Lifted[V]:
        ...


trait Monoid:
    """An identity element and an associative, ordered combination: Writer logs use one."""
    comptime Value: Movable & Deinitable
    """The combined values' type."""
    comptime Error: Movable & Deinitable = Never
    """The error `empty` and `combine` raise; `Never` by default."""
    @staticmethod
    def empty() raises Self.Error -> Self.Value:
        """The identity element: combining it with a value returns the value.

        Returns:
            The identity element.

        Raises:
            `Error`; nothing when it is `Never`.
        """
        ...
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        """Combine two values, `left` first.

        Args:
            left: The first value, consumed.
            right: The second value, consumed.

        Returns:
            The combination.

        Raises:
            `Error`; nothing when it is `Never`.
        """
        ...


# Owned iteration. An iterator continues from its current position; any other
# owned iterable starts a fresh iteration. Restarting an iterator would re-pull.
comptime _Iterator[V: Movable & Deinitable] = downcast[V, Iterator] if conforms_to(V, Iterator) else downcast[V, IterableOwned].IteratorOwnedType
comptime _Item[V: Movable & Deinitable] = downcast[_Iterator[V].Element, Movable & Deinitable]


def _iterator[V: Movable & Deinitable](var source: V) -> _Iterator[V]:
    comptime if conforms_to(V, Iterator):
        return rebind_var[_Iterator[V]](source^)
    else:
        comptime assert conforms_to(V, IterableOwned), "traverse: the source must be an iterator or an owned iterable"
        comptime I = downcast[V, IterableOwned & Movable & Deinitable]
        return rebind_var[_Iterator[V]](iter(rebind_var[I](source^)))


def _next_item[V: Movable & Deinitable](mut iterator: _Iterator[V]) -> Optional[_Item[V]]:
    """Pull the next source element through the canonical iterator advance."""
    return _next_optional[_Item[V]](iterator)


@fieldwise_init
struct _Present[B: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Mark one produced element as present."""
    comptime Arg = Self.B
    comptime Out = Optional[Self.B]
    def call(self, var arg: Self.Arg) -> Self.Out:
        return Optional(arg^)


trait _Accumulate:
    """How a traversal loop folds produced payloads into its accumulator.

    `live` tells the loop whether pulling further elements can still change the
    accumulator. `combine` must return an accumulator that is no longer live
    unchanged.
    """
    comptime Acc: Movable & Deinitable
    comptime Item: Movable & Deinitable
    comptime Error: Movable & Deinitable = Never
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        ...
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        ...
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        ...


struct _Append[B: Movable & Deinitable](_Accumulate):
    """Collect every payload in order."""
    comptime Acc = List[Self.B]
    comptime Item = Self.B
    @staticmethod
    def start() -> Self.Acc:
        return List[Self.B]()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) -> Self.Acc:
        return _append[Self.B](acc^, item^, Tuple())


def _start_as[E: Movable & Deinitable, K: _Accumulate]() raises E -> K.Acc where _ErrorCompatible[E, K.Error]:
    try:
        return K.start()
    except error:
        _propagate_error[E](error^)


def _combine_as[E: Movable & Deinitable, K: _Accumulate](var acc: K.Acc, var item: K.Item
) raises E -> K.Acc where _ErrorCompatible[E, K.Error]:
    try:
        return K.combine(acc^, item^)
    except error:
        _propagate_error[E](error^)


@fieldwise_init
struct _Fold[K: _Accumulate, o: MutOrigin](Binary):
    """Combine a present element and record whether the result is live;
    exhaustion leaves the accumulator unchanged."""
    var live: Pointer[Bool, Self.o]
    comptime First = Self.K.Acc
    comptime Second = Optional[Self.K.Item]
    comptime Out = Self.K.Acc
    comptime Error = Self.K.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        if not second:
            return first^
        # This branch proves presence; avoid a second checked take.
        var acc = Self.K.combine(first^, second.unsafe_take())
        if Self.K.live(acc):
            self.live[] = True
        return acc^


@fieldwise_init
struct _FoldShape[K: _Accumulate](BinaryContract):
    # The types and error of `_Fold`, without its scoped pointer.
    comptime First = Self.K.Acc
    comptime Second = Optional[Self.K.Item]
    comptime Out = Self.K.Acc
    comptime Error = Self.K.Error


@fieldwise_init
struct _BindFirst[F: BinaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableBinary[F] and conforms_to(F.First, Copyable),
    Copyable where conforms_to(F, Copyable) and conforms_to(F.First, Copyable)
):
    """A binary callback with its first argument retained; repeated calls copy it."""
    var function: Self.F
    var first: Self.F.First
    comptime Arg = Self.F.Second
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return call_once(self.function^, self.first^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableBinary[Self.F] and conforms_to(Self.F.First, Copyable)
        comptime C = downcast[Self.F.First, Copyable & Deinitable]
        var first = rebind_var[Self.F.First](rebind[C](self.first).copy())
        return call_repeated(self.function, first^, arg^)


@fieldwise_init
struct _UnaryView[F: UnaryContract & Movable & Deinitable, o: MutOrigin](OnceUnary):
    """Call a repeatable callback once through a pointer; the owner keeps it."""
    var function: Pointer[Self.F, Self.o]
    comptime Arg = Self.F.Arg
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F], "the callback must be repeatable"
        return call_repeated(self.function[], arg^)


struct _Lazy[G: ThunkContract & Movable & Deinitable](
    Movable, Copyable where conforms_to(G, Copyable) and conforms_to(G.Out, Copyable)
):
    """A lazy right operand: produced at most once, then retained so that
    later branches receive copies."""
    var thunk: Optional[Self.G]
    var produced: Optional[Self.G.Out]
    def __init__(out self, var thunk: Self.G):
        self.thunk = Optional(thunk^)
        self.produced = Optional[Self.G.Out]()
    def take(deinit self) raises Self.G.Error -> Self.G.Out:
        """Consume the operand: the retained value, or produce it now."""
        var produced = self.produced^
        if produced:
            return produced.unsafe_take()
        var thunk = self.thunk^
        return call_once(thunk.unsafe_take())
    def copy_value(mut self) raises Self.G.Error -> Self.G.Out:
        """Produce the operand on first use and return a copy of it."""
        comptime assert conforms_to(Self.G.Out, Copyable), "map2: repeated branches copy the right operand"
        if not self.produced:
            self.produced = Optional(call_once(self.thunk.unsafe_take()))
        comptime C = downcast[Self.G.Out, Copyable & Deinitable]
        return rebind_var[Self.G.Out](rebind[C](self.produced.value()).copy())


@fieldwise_init
struct _PullShape[O: Movable & Deinitable, FE: Movable & Deinitable, ME: Movable & Deinitable](ThunkContract):
    # Result and error of one pull, without the scoped pointers of `_Pull`.
    comptime Out = Self.O
    comptime Error = _CommonError[Self.FE, Self.ME]


@fieldwise_init
struct _Pull[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, B: Movable & Deinitable,
             io: MutOrigin, fo: MutOrigin, eo: MutOrigin](OnceThunk):
    """Pull and map the next source element, or produce exhaustion."""
    var source: Pointer[_Iterator[Self.V], origin=Self.io]
    var function: Pointer[Self.F, origin=Self.fo]
    var ended: Pointer[Bool, origin=Self.eo]
    comptime Shape = _PullShape[Self.G.Mapped[Self.F.Out, _Present[Self.B]], Self.F.Error, Self.G.MapError[Self.F.Out, _Present[Self.B]]]
    comptime Out = Self.Shape.Out
    comptime Error = Self.Shape.Error
    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F], "traverse: the callback must be repeatable"
        var item = _next_item[Self.V](self.source[])
        if not item:
            self.ended[] = True
            return rebind_var[Self.Out](Self.G.pure(Optional[Self.B]()))
        self.ended[] = False
        comptime ME = Self.G.MapError[Self.F.Out, _Present[Self.B]]
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, ME]
        # The exhaustion branch above returned; the item is present here.
        var produced = _unary_repeated_as[Self.Error](self.function[], rebind_var[Self.F.Arg](item.unsafe_take()))
        try:
            return Self.G.map(_Present[Self.B](), produced^)
        except error:
            _propagate_error[Self.Error](error^)
