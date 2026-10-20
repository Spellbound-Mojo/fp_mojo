"""Consuming method chains over native iterators."""

from std.iter import Iterator, IterableOwned
from fp.callables.protocols import Unary, Binary, BorrowCallable
from fp.data.control import ControlFlow
from fp.iteration._advance import _Source, _source
from fp.iteration.adapters import (
    MapIterator,
    FilterIterator,
    FilterMapIterator,
    FlatMapIterator,
    ScanIterator,
    _Flatten,
    map as _map,
    filter as _filter,
    filter_map as _filter_map,
    flat_map as _flat_map,
    flatten as _flatten,
    scan_left as _scan_left,
    collect_list as _collect_list,
    find as _find,
    any as _any,
    all as _all,
)
from fp.iteration.folds import (
    EmptyReductionError,
    ReductionError,
    _ReductionFailure,
    fold_left as _fold_left,
    fold_until as _fold_until,
    reduce as _reduce,
    reduce_optional as _reduce_optional,
)


struct Iter[I: Iterator](Iterator, IterableOwned):
    """A native iterator with consuming transformation and terminal methods.

    Start a chain with `iterated(source)`. The wrapper stores only the native
    iterator and preserves its current position and embedded origins. Methods
    use the same implementations and contracts as the free functions.

    Parameters:
        I: The concrete native iterator type, including any borrowed origins.
    """

    comptime Element = Self.I.Element
    """The underlying iterator's element type."""
    comptime IteratorOwnedType = Self
    """Consuming iteration keeps the same wrapper and its position."""
    var _iterator: Self.I

    def __init__(out self, var iterator: Self.I):
        """Wrap a native iterator at its current position."""
        self._iterator = iterator^

    def __iter__(var self) -> Self:
        """Consume the wrapper without restarting its iterator."""
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        """Advance the underlying native iterator once."""
        return self._iterator.__next__()

    def bounds(self) -> Tuple[Int, Optional[Int]]:
        """Return the underlying iterator's remaining length bounds.

        Returns:
            The lower bound and optional upper bound, forwarded unchanged.
        """
        return self._iterator.bounds()

    # Native thin functions and closures keep their own admission signatures,
    # as in the free factories. Do not erase F or promote it to a library
    # callable: its exact type retains captures and embedded origins.
    def map[T: Movable & Deinitable, U: Movable & Deinitable](
        deinit self, function: def(var T) thin -> U
    ) -> Iter[MapIterator[T, U, Self.I]] where Self.I.Element == T:
        """Lazily transform each element and continue the chain.

        Each element is moved into the stored callback. Construction pulls nothing.
        Plain functions, capturing closures and non-raising library `Unary` values
        use the same admission and execution as the free `map`.

        Parameters:
            T: The source element type.
            U: The result element type.

        Args:
            function: The non-raising callback, stored; move owned captures in with `^`.

        Returns:
            An `Iter` over the transformed elements.
        """
        return Iter(_map(function, self._iterator^))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //,
            F: def(var T) -> U](
        deinit self, var function: F
    ) -> Iter[MapIterator[T, U, Self.I, F]] where Self.I.Element == T:
        """Lazily transform each element with a stored closure."""
        return Iter(_map(function^, self._iterator^))

    def map[F: Unary](deinit self, var function: F
    ) -> Iter[MapIterator[F.Arg, F.Out, Self.I, F]] where Self.I.Element == F.Arg and F.Error == Never:
        """Lazily transform each element with a library `Unary` value."""
        return Iter(_map(function^, self._iterator^))

    def filter[T: Movable & Deinitable](
        deinit self, predicate: def(T) thin -> Bool
    ) -> Iter[FilterIterator[T, Self.I]] where Self.I.Element == T:
        """Lazily retain the original elements a borrowing predicate accepts.

        The predicate borrows each candidate. Rejected elements are destroyed;
        accepted elements are moved out unchanged. Plain functions, closures and
        non-raising `BorrowCallable` values are supported.

        Parameters:
            T: The source element type.

        Args:
            predicate: The non-raising predicate, stored.

        Returns:
            An `Iter` over accepted elements, in source order.
        """
        return Iter(_filter(predicate, self._iterator^))

    def filter[T: Movable & Deinitable, //, F: def(T) -> Bool](
        deinit self, var predicate: F
    ) -> Iter[FilterIterator[T, Self.I, F]] where Self.I.Element == T:
        """Lazily retain elements with a stored closure predicate."""
        return Iter(_filter(predicate^, self._iterator^))

    def filter[C: BorrowCallable](deinit self, var predicate: C
    ) -> Iter[FilterIterator[Self.I.Element, Self.I, C]] where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool and C.Failure == Never:
        """Lazily retain elements with a library borrowing predicate."""
        return Iter(_filter(predicate^, self._iterator^))

    def filter_map[T: Movable & Deinitable, U: Movable & Deinitable](
        deinit self, function: def(var T) thin -> Optional[U]
    ) -> Iter[FilterMapIterator[T, U, Self.I]] where Self.I.Element == T:
        """Lazily transform elements, yielding present values and skipping `None`.

        Moves each element into the callback. Only absent `Optional` values are
        skipped; a present `Result.Err` remains an ordinary element. Library
        `Unary` callbacks name the result element parameter explicitly, `U=U`.

        Parameters:
            T: The source element type.
            U: The element inside the returned `Optional`.

        Args:
            function: The non-raising callback returning `Optional[U]`, stored.

        Returns:
            An `Iter` over present results.
        """
        return Iter(_filter_map(function, self._iterator^))

    def filter_map[T: Movable & Deinitable, U: Movable & Deinitable, //,
                   F: def(var T) -> Optional[U]](
        deinit self, var function: F
    ) -> Iter[FilterMapIterator[T, U, Self.I, F]] where Self.I.Element == T:
        """Lazily transform and filter elements with a stored closure."""
        return Iter(_filter_map(function^, self._iterator^))

    def filter_map[U: Movable & Deinitable, F: Unary](deinit self, var function: F
    ) -> Iter[FilterMapIterator[F.Arg, U, Self.I, F]] where Self.I.Element == F.Arg and F.Out == Optional[U] and F.Error == Never:
        """Lazily filter a library `Unary` result; name `U` explicitly."""
        return Iter(_filter_map[U=U](function^, self._iterator^))

    def flat_map[T: Movable & Deinitable, U: Movable & Deinitable](
        deinit self, function: def(var T) thin -> U
    ) -> Iter[FlatMapIterator[T, U, Self.I]] where Self.I.Element == T:
        """Lazily expand each element and exhaust its inner source in order.

        Moves each element into the callback and retains the returned native
        iterator or owned iterable until it is exhausted or abandoned. Empty inner
        sources are skipped. A borrowed inner source retains its external origin.
        Plain functions, closures and non-raising library `Unary` values are supported.

        Parameters:
            T: The source element type.
            U: The inner iterator or owned iterable returned by the callback.

        Args:
            function: The non-raising callback, stored; move owned captures in with `^`.

        Returns:
            An `Iter` over the concatenated inner elements.
        """
        return Iter(_flat_map(function, self._iterator^))

    def flat_map[T: Movable & Deinitable, U: Movable & Deinitable, //,
                 F: def(var T) -> U](
        deinit self, var function: F
    ) -> Iter[FlatMapIterator[T, U, Self.I, F]] where Self.I.Element == T:
        """Lazily expand each element with a stored closure."""
        return Iter(_flat_map(function^, self._iterator^))

    def flat_map[F: Unary](deinit self, var function: F
    ) -> Iter[FlatMapIterator[F.Arg, F.Out, Self.I, F]] where Self.I.Element == F.Arg and F.Error == Never:
        """Lazily expand elements with a library `Unary` value."""
        return Iter(_flat_map(function^, self._iterator^))

    def flatten[S: Movable & Deinitable](deinit self
    ) -> Iter[_Flatten[Self.I, S]] where Self.I.Element == S:
        """Lazily concatenate inner sources, skipping empty ones.

        Exhausts each inner iterator or owned iterable before pulling another
        outer element. Borrowed inner owners must remain alive and unmoved.

        Parameters:
            S: The inner source type, inferred from this iterator's element type.

        Returns:
            An `Iter` over the concatenated inner elements.
        """
        return Iter(_flatten[I=Self.I, S=S](self._iterator^))

    def scan_left[A: Copyable & Deinitable, T: Movable & Deinitable](
        deinit self, step: def(var A, var T) thin -> A, var initial: A
    ) -> Iter[ScanIterator[A, T, Self.I]] where Self.I.Element == T:
        """Lazily yield the initial accumulator and a copy after each step.

        The first output copies `initial` without pulling an input. Each later
        output applies the step once, then copies the accumulator. An input of
        length `n` yields `n + 1` snapshots. Closures and non-raising library
        `Binary` steps retain the same contract as the free `scan_left`.

        Parameters:
            A: The copyable accumulator type.
            T: The source element type.

        Args:
            step: The non-raising step, stored.
            initial: The initial accumulator, consumed.

        Returns:
            An `Iter` over the accumulator snapshots.
        """
        return Iter(_scan_left(step, initial^, self._iterator^))

    def scan_left[A: Copyable & Deinitable, T: Movable & Deinitable, //,
                  F: def(var A, var T) -> A](
        deinit self, var step: F, var initial: A
    ) -> Iter[ScanIterator[A, T, Self.I, F]] where Self.I.Element == T:
        """Lazily yield accumulator snapshots with a stored closure."""
        return Iter(_scan_left(step^, initial^, self._iterator^))

    def scan_left[A: Copyable & Deinitable, F: Binary](
        deinit self, var step: F, var initial: A
    ) -> Iter[ScanIterator[A, F.Second, Self.I, F]] where F.First == A and F.Second == Self.I.Element and F.Out == A and F.Error == Never:
        """Lazily yield accumulator snapshots with a library `Binary` step."""
        return Iter(_scan_left(step^, initial^, self._iterator^))

    def to_list(deinit self) -> List[Self.Element] where conforms_to(Self.Element, Deinitable):
        """Consume the remaining elements into a list, in order.

        Elements must be deinitializable, as for the free `collect_list`.
        Each element moves into the result; no copy requirement is added.
        Takes linear time and storage in the number of remaining elements.

        Returns:
            A `List[Element]`; an empty list when the source is exhausted.
        """
        return _collect_list[T=Self.Element](self._iterator^)

    def collect_list(deinit self) -> List[Self.Element] where conforms_to(Self.Element, Deinitable):
        """Alias of `to_list`; consumes the remaining elements into a list.

        Returns:
            A `List[Element]`, with the same ownership and empty-input
            behavior as `to_list` and the free `collect_list`.
        """
        return self^.to_list()

    def fold_left[A: Movable & Deinitable, T: Movable & Deinitable, //,
                  F: def(var A, var T) -> A](
        deinit self, step: F, var initial: A
    ) -> A where Self.I.Element == T:
        """Consume elements in order into an accumulator.

        Empty input returns `initial` without calling the step. Steps are never
        reassociated. The callback is borrowed and may be a plain function, a
        closure or a library `Binary` value. Raising overloads propagate the
        step's exact error type and stop without another pull.

        Parameters:
            A: The accumulator type.
            T: The source element type.
            F: The native step type.

        Args:
            step: The step, borrowed for the duration of the fold.
            initial: The initial accumulator, consumed.

        Returns:
            The final accumulator, moved out.
        """
        return _fold_left(step, initial^, self._iterator^)

    # Pass E explicitly through every raising boundary. Reading F.E or inferring
    # it again loses the caller's error equality in precompiled generic clients.
    def fold_left[A: Movable & Deinitable, T: Movable & Deinitable, E: AnyType, //,
                  F: def(var A, var T) raises E -> A](
        deinit self, step: F, var initial: A
    ) raises E -> A where Self.I.Element == T:
        """Fold with a raising step, propagating its exact error type."""
        return _fold_left[E=E](step, initial^, self._iterator^)

    def fold_left[A: Movable & Deinitable, F: Binary](
        deinit self, step: F, var initial: A
    ) raises F.Error -> A where F.First == A and F.Second == Self.I.Element and F.Out == A:
        """Fold with a library `Binary` step."""
        return _fold_left(step, initial^, self._iterator^)

    def fold_until[A: Movable & Deinitable, B: Movable & Deinitable,
                   T: Movable & Deinitable, //,
                   F: def(var A, var T) -> ControlFlow[B, A]](
        deinit self, step: F, var initial: A
    ) -> ControlFlow[B, A] where Self.I.Element == T:
        """Fold until `Break`, or return `Continue` with the final accumulator.

        A break returns immediately without another pull. Empty input returns
        `Continue(initial)`. Raising overloads preserve the step's error as a
        separate outcome from a `Break`. Library `Binary` steps are also accepted.

        Parameters:
            A: The accumulator type.
            B: The break payload type.
            T: The source element type.
            F: The native step type.

        Args:
            step: The step returning `ControlFlow[B, A]`, borrowed.
            initial: The initial accumulator, consumed.

        Returns:
            The first `Break`, or `Continue` with the final accumulator.
        """
        return _fold_until(step, initial^, self._iterator^)

    def fold_until[A: Movable & Deinitable, B: Movable & Deinitable,
                   T: Movable & Deinitable, E: Movable & Deinitable, //,
                   F: def(var A, var T) raises E -> ControlFlow[B, A]](
        deinit self, step: F, var initial: A
    ) raises E -> ControlFlow[B, A] where Self.I.Element == T:
        """Fold until `Break` with a raising step, preserving its error."""
        return _fold_until[E=E](step, initial^, self._iterator^)

    def fold_until[B: Movable & Deinitable, A: Movable & Deinitable, F: Binary](
        deinit self, step: F, var initial: A
    ) raises F.Error -> ControlFlow[B, A] where F.First == A and F.Second == Self.I.Element and F.Out == ControlFlow[B, A]:
        """Fold until `Break` with a library `Binary` step."""
        return _fold_until[B=B](step, initial^, self._iterator^)

    def reduce[T: Movable & Deinitable, //, F: def(var T, var T) -> T](
        deinit self, step: F
    ) raises EmptyReductionError -> T where Self.I.Element == T:
        """Reduce from the first element; empty input raises `EmptyReductionError`.

        A non-empty input of length `n` calls the step `n - 1` times. The overload
        with `initial=` instead folds every element from that accumulator. Raising
        uninitialized reductions distinguish empty input and step failure with
        `ReductionError[E]`; initialized reductions propagate `E` directly.
        Library `Binary` steps preserve the same contracts.

        Parameters:
            T: The element and accumulator type.
            F: The native step type.

        Args:
            step: The step, borrowed.

        Returns:
            The reduced value, moved out.

        Raises:
            EmptyReductionError: The source is empty and no initializer was supplied.
        """
        return _reduce(step, self._iterator^)

    def reduce[T: Movable & Deinitable, E: Movable & Deinitable, //,
               F: def(var T, var T) raises E -> T](
        deinit self, step: F
    ) raises ReductionError[E] -> T where Self.I.Element == T:
        """Reduce with a raising step, distinguishing step failure from empty input."""
        return _reduce[E=E](step, self._iterator^)

    def reduce[F: Binary](deinit self, step: F
    ) raises _ReductionFailure[F.Error] -> F.Out where F.First == F.Out and F.Second == F.Out and Self.I.Element == F.Out:
        """Reduce from the first element with a library `Binary` step."""
        return _reduce(step, self._iterator^)

    def reduce[A: Movable & Deinitable, T: Movable & Deinitable, //,
               F: def(var A, var T) -> A](
        deinit self, step: F, *, var initial: A
    ) -> A where Self.I.Element == T:
        """Reduce from an explicit initial accumulator, as `fold_left` does."""
        return _reduce(step, self._iterator^, initial=initial^)

    def reduce[A: Movable & Deinitable, T: Movable & Deinitable,
               E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](
        deinit self, step: F, *, var initial: A
    ) raises E -> A where Self.I.Element == T:
        """Reduce from an initial accumulator, preserving the step's error."""
        return _reduce[E=E](step, self._iterator^, initial=initial^)

    def reduce[A: Movable & Deinitable, F: Binary](
        deinit self, step: F, *, var initial: A
    ) raises F.Error -> A where F.First == A and F.Second == Self.I.Element and F.Out == A:
        """Reduce from an initial accumulator with a library `Binary` step."""
        return _reduce(step, self._iterator^, initial=initial^)

    def reduce_optional[T: Movable & Deinitable, //, F: def(var T, var T) -> T](
        deinit self, step: F
    ) -> Optional[T] where Self.I.Element == T:
        """Reduce from the first element, returning `None` for empty input.

        Only empty input becomes absence. Raising overloads propagate the exact
        step error, including `StopIteration`, and stop without another pull.
        Library `Binary` steps are also accepted.

        Parameters:
            T: The element and accumulator type.
            F: The native step type.

        Args:
            step: The step, borrowed.

        Returns:
            The reduced value inside `Optional`, or `None`.
        """
        return _reduce_optional(step, self._iterator^)

    def reduce_optional[T: Movable & Deinitable, E: AnyType, //,
                        F: def(var T, var T) raises E -> T](
        deinit self, step: F
    ) raises E -> Optional[T] where Self.I.Element == T:
        """Reduce with a raising step; only empty input becomes `None`."""
        return _reduce_optional[E=E](step, self._iterator^)

    def reduce_optional[F: Binary](deinit self, step: F
    ) raises F.Error -> Optional[F.Out] where F.First == F.Out and F.Second == F.Out and Self.I.Element == F.Out:
        """Reduce with a library `Binary` step, returning `None` for empty input."""
        return _reduce_optional(step, self._iterator^)

    def find[T: Movable & Deinitable, //, F: def(T) -> Bool](
        deinit self, predicate: F
    ) -> Optional[T] where Self.I.Element == T:
        """Consume through the first accepted element; no match returns `None`.

        The predicate borrows each candidate. The first accepted original value
        is returned without pulling another element. Raising predicates keep
        their error type. Library `BorrowCallable` predicates are also accepted.

        Parameters:
            T: The element type.
            F: The native predicate type.

        Args:
            predicate: The predicate, borrowed.

        Returns:
            The first accepted element inside `Optional`, or `None`.
        """
        return _find(predicate, self._iterator^)

    def find[T: Movable & Deinitable, E: Movable & Deinitable, //,
             F: def(T) raises E -> Bool](
        deinit self, predicate: F
    ) raises E -> Optional[T] where Self.I.Element == T:
        """Find with a raising predicate, propagating its exact error."""
        return _find[E=E](predicate, self._iterator^)

    def find[C: BorrowCallable](deinit self, predicate: C
    ) raises C.Failure -> Optional[Self.I.Element] where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool:
        """Find with a library borrowing predicate."""
        return _find(predicate, self._iterator^)

    def any[T: Movable & Deinitable, //, F: def(T) -> Bool](
        deinit self, predicate: F
    ) -> Bool where Self.I.Element == T:
        """Stop at the first accepted element; empty input returns `False`.

        The predicate borrows each candidate. A decisive result or predicate
        error stops without another pull. Raising predicates preserve their error
        type, and library `BorrowCallable` predicates are supported.

        Parameters:
            T: The element type.
            F: The native predicate type.

        Args:
            predicate: The predicate, borrowed.

        Returns:
            `True` if any element is accepted, otherwise `False`.
        """
        return _any(predicate, self._iterator^)

    def any[T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(T) raises E -> Bool](
        deinit self, predicate: F
    ) raises E -> Bool where Self.I.Element == T:
        """Test any element with a raising predicate, preserving its error."""
        return _any[E=E](predicate, self._iterator^)

    def any[C: BorrowCallable](deinit self, predicate: C
    ) raises C.Failure -> Bool where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool:
        """Test any element with a library borrowing predicate."""
        return _any(predicate, self._iterator^)

    def all[T: Movable & Deinitable, //, F: def(T) -> Bool](
        deinit self, predicate: F
    ) -> Bool where Self.I.Element == T:
        """Stop at the first rejected element; empty input returns `True`.

        The predicate borrows each candidate. A decisive result or predicate
        error stops without another pull. Raising predicates preserve their error
        type, and library `BorrowCallable` predicates are supported.

        Parameters:
            T: The element type.
            F: The native predicate type.

        Args:
            predicate: The predicate, borrowed.

        Returns:
            `True` if every element is accepted, otherwise `False`.
        """
        return _all(predicate, self._iterator^)

    def all[T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(T) raises E -> Bool](
        deinit self, predicate: F
    ) raises E -> Bool where Self.I.Element == T:
        """Test every element with a raising predicate, preserving its error."""
        return _all[E=E](predicate, self._iterator^)

    def all[C: BorrowCallable](deinit self, predicate: C
    ) raises C.Failure -> Bool where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool:
        """Test every element with a library borrowing predicate."""
        return _all(predicate, self._iterator^)


def iterated[S: Movable & Deinitable](var source: S) -> Iter[_Source[S]]:
    """Start a consuming method chain over an iterator or owned collection.

    An iterator keeps its current position. An owned collection is consumed
    through its native owned iterator. Pass `iter(values)` to borrow a
    collection, keeping the owner alive and unmoved while the chain is used.
    Construction does not pull any elements or run callbacks.

    Parameters:
        S: A native iterator or an `IterableOwned` collection.

    Args:
        source: The source, consumed.

    Returns:
        A native `Iterator` and `IterableOwned` wrapper with chaining methods.
    """
    return Iter(_source(source^))
