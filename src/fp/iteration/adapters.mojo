"""Lazy adapters and terminal operations that the standard library does not provide.

A source is a native iterator or an owned collection (`IterableOwned`), which is
consumed. Lazy callbacks do not raise; `Result` is an ordinary element.
Standard `chain`, `zip`, `take` and the like stay in `std.iter` and
`std.itertools`.
"""

from std.iter import Iterator, IterableOwned, iter
from std.builtin.rebind import downcast, rebind_var
from fp.iteration._advance import _next_fused, _Source, _source
from fp.iteration._terminal import _find, _quantify, _collect_list
from fp.iteration._callbacks import _predicate_plain, _predicate_raising, _LazyUnary, _LazyStep, _apply_lazy_unary, _apply_lazy_step, _LazyPredicate, _LazyOptional, _apply_lazy_predicate, _apply_lazy_optional
from fp.callables.protocols import Unary, Binary
from fp.callables.protocols import BorrowCallable
from fp.iteration._callbacks import _predicate_callable


@fieldwise_init
struct _Map[T: Movable & Deinitable, U: Movable & Deinitable,
            I: Iterator, F: Movable & Deinitable = def(var T) thin -> U](Iterator, IterableOwned):
    comptime Element = Self.U
    comptime IteratorOwnedType = Self
    var function: Self.F
    var source: Self.I
    var done: Bool

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "map: source element type must match T"
        var item = _next_fused(self.source, self.done)
        var value = rebind_var[Self.T](item^)
        return _apply_lazy_unary[Self.T, Self.U](self.function, value^)

def map[T: Movable & Deinitable, U: Movable & Deinitable, I: Movable & Deinitable, //](
    function: def(var T) thin -> U, var source: I
) -> _Map[T, U, _Source[I]] where _Source[I].Element == T:
    """Lazily apply `function` to each element: `function(x0), function(x1), ...`.

    Each element is moved into the function, so move-only elements and results
    work. Nothing is pulled until the first `next`, and each output pulls one
    element.

    Parameters:
        T: The element type.
        U: The result type.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.

    Args:
        function: A plain function, stored.
        source: The source, consumed.

    Returns:
        A `MapIterator`, a native iterator of the results.
    """
    return _Map[T, U, _Source[I]](function, _source(source^), False)


def map[T: Movable & Deinitable, U: Movable & Deinitable, I: Movable & Deinitable, //,
        F: _LazyUnary[T, U]](var function: F, var source: I) -> _Map[T, U, _Source[I], F] where _Source[I].Element == T:
    """Lazily apply a closure; move one that owns non-trivial state in with `function^`."""
    return _Map[T, U, _Source[I], F](function^, _source(source^), False)


@fieldwise_init
struct _Filter[T: Movable & Deinitable, I: Iterator,
               F: Movable & Deinitable = def(T) thin -> Bool](Iterator, IterableOwned):
    comptime Element = Self.T
    comptime IteratorOwnedType = Self
    var function: Self.F
    var source: Self.I
    var done: Bool

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "filter: source element type must match T"
        while True:
            var item = _next_fused(self.source, self.done)
            var value = rebind_var[Self.T](item^)
            if _apply_lazy_predicate[Self.T](self.function, value): return value^

def filter[T: Movable & Deinitable, I: Movable & Deinitable, //](
    function: def(T) thin -> Bool, var source: I
) -> _Filter[T, _Source[I]] where _Source[I].Element == T:
    """Lazily keep the elements `predicate` accepts.

    The predicate borrows each candidate, and the original element is yielded
    unchanged. Each output pulls until a candidate is accepted.

    Parameters:
        T: The element type.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.

    Args:
        function: The predicate, a plain function, stored.
        source: The source, consumed.

    Returns:
        A `FilterIterator`, a native iterator of the accepted elements.
    """
    return _Filter[T, _Source[I]](function, _source(source^), False)


def filter[T: Movable & Deinitable, I: Movable & Deinitable, //, F: _LazyPredicate[T]](
    var function: F, var source: I
) -> _Filter[T, _Source[I], F] where _Source[I].Element == T:
    """Lazily keep the elements a closure predicate accepts."""
    return _Filter[T, _Source[I], F](function^, _source(source^), False)


@fieldwise_init
struct _FilterMap[T: Movable & Deinitable, U: Movable & Deinitable,
                  I: Iterator, F: Movable & Deinitable = def(var T) thin -> Optional[U]](Iterator, IterableOwned):
    comptime Element = Self.U
    comptime IteratorOwnedType = Self
    var function: Self.F
    var source: Self.I
    var done: Bool

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "filter_map: source element type must match T"
        while True:
            var item = _next_fused(self.source, self.done)
            var value = rebind_var[Self.T](item^)
            var result = _apply_lazy_optional[Self.T, Self.U](self.function, value^)
            if result: return result.take()

def filter_map[T: Movable & Deinitable, U: Movable & Deinitable, I: Movable & Deinitable, //](
    function: def(var T) thin -> Optional[U], var source: I
) -> _FilterMap[T, U, _Source[I]] where _Source[I].Element == T:
    """Lazily apply `function` and keep the present results.

    Each element is moved into the function. Only `None` is skipped: a present
    `Result.Err` is an ordinary output.

    Parameters:
        T: The element type.
        U: The type of a present result.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.

    Args:
        function: A plain function returning `Optional[U]`, stored.
        source: The source, consumed.

    Returns:
        A `FilterMapIterator`, a native iterator of the present results.
    """
    return _FilterMap[T, U, _Source[I]](function, _source(source^), False)


def filter_map[T: Movable & Deinitable, U: Movable & Deinitable, I: Movable & Deinitable, //,
               F: _LazyOptional[T, U]](var function: F, var source: I) -> _FilterMap[T, U, _Source[I], F] where _Source[I].Element == T:
    """Lazily apply a closure returning `Optional[U]` and keep the present results."""
    return _FilterMap[T, U, _Source[I], F](function^, _source(source^), False)


# An inner iterator may borrow an external owner; its native type retains that
# origin. An owned inner collection is consumed into its own native iterator.
# Never construct a self-borrow between two fields of a movable flatten adapter.
@fieldwise_init
struct _Flatten[I: Iterator, S: Movable & Deinitable](Iterator, IterableOwned):
    comptime Inner = _Source[Self.S]
    comptime Element = Self.Inner.Element
    comptime IteratorOwnedType = Self
    var source: Self.I
    var current: Optional[Self.Inner]
    var done: Bool

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        if self.done: raise StopIteration()
        while True:
            if self.current:
                try:
                    return self.current.value().__next__()
                except:
                    self.current = None
            var item = _next_fused(self.source, self.done)
            self.current = _source(rebind_var[Self.S](item^))


def flatten[I: Movable & Deinitable, S: Movable & Deinitable](
    var source: I
) -> _Flatten[_Source[I], S] where _Source[I].Element == S:
    """Lazily concatenate the inner sources a source yields.

    Each inner source, a native iterator or an owned iterable, is exhausted
    before the next outer element is pulled, and empty inner sources are
    skipped. An inner iterator may borrow an external owner, which must stay
    alive.

    Parameters:
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        S: The inner source's type.

    Args:
        source: The source of inner sources, consumed.

    Returns:
        A native iterator of the inner elements, in order.
    """
    return _Flatten[_Source[I], S](_source(source^), None, False)


def flat_map[T: Movable & Deinitable, S: Movable & Deinitable, I: Movable & Deinitable](
    function: def(var T) thin -> S, var source: I
) -> _Flatten[_Map[T, S, _Source[I]], S] where _Source[I].Element == T:
    """Lazily apply `function` and concatenate the inner sources it returns: `flatten(map(function, source))`.

    The returned inner iterator or iterable is kept until it is exhausted or
    the adapter is abandoned.

    Parameters:
        T: The element type.
        S: The returned inner source's type: a native iterator or an owned iterable.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.

    Args:
        function: A plain function, stored.
        source: The source, consumed.

    Returns:
        A `FlatMapIterator`, a native iterator of the inner elements.
    """
    var mapped = map(function, source^)
    return flatten(mapped^)


# Keep T/U aligned with the native alias: the tested T/S spelling loses
# callable conformance through the nested map on Mojo 1.1.0.
def flat_map[T: Movable & Deinitable, U: Movable & Deinitable, I: Movable & Deinitable, //,
             F: _LazyUnary[T, U]](var function: F, var source: I) -> _Flatten[_Map[T, U, _Source[I], F], U] where _Source[I].Element == T:
    """Lazily apply a closure and concatenate the inner sources it returns."""
    comptime assert conforms_to(U, Iterator) or conforms_to(U, IterableOwned), "flat_map: native inner required"
    var mapped = map(function^, source^)
    return flatten(mapped^)


@fieldwise_init
struct _Scan[A: Copyable & Deinitable, T: Movable & Deinitable,
             I: Iterator, F: Movable & Deinitable = def(var A, var T) thin -> A](Iterator, IterableOwned):
    comptime Element = Self.A
    comptime IteratorOwnedType = Self
    var function: Self.F
    var accumulator: Self.A
    var source: Self.I
    var started: Bool
    var done: Bool

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "scan_left: source element type must match T"
        if self.done: raise StopIteration()
        if not self.started:
            self.started = True
            return self.accumulator.copy()
        var item = _next_fused(self.source, self.done)
        self.accumulator = _apply_lazy_step[Self.A, Self.T](self.function, self.accumulator^, rebind_var[Self.T](item^))
        return self.accumulator.copy()


def scan_left[A: Copyable & Deinitable, T: Movable & Deinitable, I: Movable & Deinitable](
    function: def(var A, var T) thin -> A, var initial: A, var source: I
) -> _Scan[A, T, _Source[I]] where _Source[I].Element == T:
    """Lazily yield `initial` and then the accumulator after each step: `n + 1` values for `n` elements.

    The initial value is yielded before the first pull. Each yielded value is a
    native copy of the accumulator, so retaining them costs their storage; a
    shared-reference payload is not deep-cloned. For an eager scan with separate
    carry and output values and no copies, use `fp.control.scan`.

    Parameters:
        A: The accumulator type, which must be `Copyable`.
        T: The element type.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.

    Args:
        function: A plain function `(var A, var T) -> A`, stored.
        initial: The first accumulator, consumed.
        source: The source, consumed.

    Returns:
        A `ScanIterator`, a native iterator of the accumulator snapshots.
    """
    return _Scan[A, T, _Source[I]](function, initial^, _source(source^), False, False)


def scan_left[A: Copyable & Deinitable, T: Movable & Deinitable, I: Movable & Deinitable, //,
              F: _LazyStep[A, T]](var function: F, var initial: A, var source: I) -> _Scan[A, T, _Source[I], F] where _Source[I].Element == T:
    """Lazily yield the snapshots of a scan with a closure step."""
    return _Scan[A, T, _Source[I], F](function^, initial^, _source(source^), False, False)


def collect_list[T: Movable & Deinitable, I: Movable & Deinitable](
    var source: I
) -> List[T] where _Source[I].Element == T:
    """Collect every element of a source into a `List`, in order.

    Parameters:
        T: The element type.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.

    Args:
        source: The source, consumed.

    Returns:
        A `List` of the elements, moved in; empty for an empty source.
    """
    return _collect_list[T, _Source[I]](_source(source^))


def find[T: Movable & Deinitable, I: Movable & Deinitable, //, F: def(T) -> Bool](
    predicate: F, var source: I
) -> Optional[T] where _Source[I].Element == T:
    """Return the first element `predicate` accepts, without pulling another.

    The predicate borrows each candidate; the accepted element is returned as
    it is, and rejected ones are destroyed.

    Parameters:
        T: The element type.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The predicate's type: a plain function or a closure.

    Args:
        predicate: The predicate, borrowed.
        source: The source, consumed.

    Returns:
        The first accepted element, or `None` when there is none.
    """
    return _find[T, _Source[I], Never, F, _predicate_plain[T, F]](predicate, _source(source^))

def any[T: Movable & Deinitable, I: Movable & Deinitable, //, F: def(T) -> Bool](
    predicate: F, var source: I
) -> Bool where _Source[I].Element == T:
    """Whether `predicate` accepts some element; stops at the first accepted one.

    Parameters:
        T: The element type.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The predicate's type: a plain function or a closure.

    Args:
        predicate: The predicate, borrowed; it borrows each candidate.
        source: The source, consumed.

    Returns:
        `True` at the first accepted element; `False` for an empty source.
    """
    return _quantify[T, _Source[I], Never, F, _predicate_plain[T, F]](predicate, _source(source^), True)


def all[T: Movable & Deinitable, I: Movable & Deinitable, //, F: def(T) -> Bool](
    predicate: F, var source: I
) -> Bool where _Source[I].Element == T:
    """Whether `predicate` accepts every element; stops at the first rejected one.

    Parameters:
        T: The element type.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The predicate's type: a plain function or a closure.

    Args:
        predicate: The predicate, borrowed; it borrows each candidate.
        source: The source, consumed.

    Returns:
        `False` at the first rejected element; `True` for an empty source.
    """
    return _quantify[T, _Source[I], Never, F, _predicate_plain[T, F]](predicate, _source(source^), False)


def find[T: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
         F: def(T) raises E -> Bool](
    predicate: F, var source: I
) raises E -> Optional[T] where _Source[I].Element == T:
    """Return the first accepted element with a raising predicate; its error stops the search."""
    return _find[T, _Source[I], E, F, _predicate_raising[T, E, F]](predicate, _source(source^))

def any[T: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
         F: def(T) raises E -> Bool](
    predicate: F, var source: I
) raises E -> Bool where _Source[I].Element == T:
    """Whether a raising predicate accepts some element; its error stops the search."""
    return _quantify[T, _Source[I], E, F, _predicate_raising[T, E, F]](predicate, _source(source^), True)


def all[T: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
         F: def(T) raises E -> Bool](
    predicate: F, var source: I
) raises E -> Bool where _Source[I].Element == T:
    """Whether a raising predicate accepts every element; its error stops the search."""
    return _quantify[T, _Source[I], E, F, _predicate_raising[T, E, F]](predicate, _source(source^), False)


# Stable return-annotation names for values constructed by the lazy factories.
# Retain the concrete callback and source (including their native origins).
# Factories constrain source elements; advancement checks nominal equality too.
# Keeping these aliases unconstrained permits nested generic return annotations.
comptime MapIterator[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, F: Movable & Deinitable = def(var T) thin -> U] = _Map[T, U, I, F]
"""The type `map` returns, for a generic function's return annotation.

Parameters:
    T: The element type.
    U: The result type.
    I: The native iterator over the source.
    F: The function's type; the thin function type by default.
"""

comptime ScanIterator[A: Copyable & Deinitable, T: Movable & Deinitable, I: Iterator, F: Movable & Deinitable = def(var A, var T) thin -> A] = _Scan[A, T, I, F]
"""The type `scan_left` returns, for a generic function's return annotation.

Parameters:
    A: The accumulator type.
    T: The element type.
    I: The native iterator over the source.
    F: The step's type; the thin function type by default.
"""


comptime FilterIterator[T: Movable & Deinitable, I: Iterator, F: Movable & Deinitable = def(T) thin -> Bool] = _Filter[T, I, F]
"""The type `filter` returns, for a generic function's return annotation.

Parameters:
    T: The element type.
    I: The native iterator over the source.
    F: The predicate's type; the thin function type by default.
"""
comptime FilterMapIterator[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, F: Movable & Deinitable = def(var T) thin -> Optional[U]] = _FilterMap[T, U, I, F]
"""The type `filter_map` returns, for a generic function's return annotation.

Parameters:
    T: The element type.
    U: The type of a present result.
    I: The native iterator over the source.
    F: The function's type; the thin function type by default.
"""
comptime FlatMapIterator[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, F: Movable & Deinitable = def(var T) thin -> U] = _Flatten[_Map[T, U, I, F], U]
"""The type `flat_map` returns, for a generic function's return annotation.

Parameters:
    T: The element type.
    U: The inner source the function returns, not the final element.
    I: The native iterator over the source.
    F: The function's type; the thin function type by default.
"""


# Fixed-arity library callables with a shared receiver, such as partials.
def map[I: Movable & Deinitable, F: Unary](var function: F, var source: I
) -> _Map[F.Arg, F.Out, _Source[I], F] where _Source[I].Element == F.Arg and F.Error == Never:
    """Lazily apply a library `Unary` value, such as a partial or a composition."""
    return _Map[F.Arg, F.Out, _Source[I], F](function^, _source(source^), False)


def filter_map[U: Movable & Deinitable, I: Movable & Deinitable, F: Unary](var function: F, var source: I
) -> _FilterMap[F.Arg, U, _Source[I], F] where _Source[I].Element == F.Arg and F.Out == Optional[U] and F.Error == Never:
    """Lazily apply a library `Unary` value returning `Optional[U]`; name `U` explicitly."""
    return _FilterMap[F.Arg, U, _Source[I], F](function^, _source(source^), False)


def flat_map[I: Movable & Deinitable, F: Unary](var function: F, var source: I
) -> _Flatten[_Map[F.Arg, F.Out, _Source[I], F], F.Out] where _Source[I].Element == F.Arg and F.Error == Never:
    """Lazily apply a library `Unary` value and concatenate the inner sources it returns."""
    return flatten(map(function^, source^))


def scan_left[A: Copyable & Deinitable, I: Movable & Deinitable, F: Binary](var function: F, var initial: A, var source: I
) -> _Scan[A, F.Second, _Source[I], F] where F.First == A and F.Second == _Source[I].Element and F.Out == A and F.Error == Never:
    """Lazily yield the snapshots of a scan with a library `Binary` step."""
    return _Scan[A, F.Second, _Source[I], F](function^, initial^, _source(source^), False, False)


def filter[I: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: I
) -> _Filter[_Source[I].Element, _Source[I], C] where conforms_to(_Source[I].Element, Movable & Deinitable) and C.Payload == _Source[I].Element and C.Result == Bool and C.Failure == Never:
    """Lazily keep the elements a `BorrowCallable` predicate accepts."""
    return _Filter[_Source[I].Element, _Source[I], C](predicate^, _source(source^), False)


def find[I: Movable & Deinitable, C: BorrowCallable](predicate: C, var source: I
) raises C.Failure -> Optional[_Source[I].Element] where conforms_to(_Source[I].Element, Movable & Deinitable) and C.Payload == _Source[I].Element and C.Result == Bool:
    """Return the first element a `BorrowCallable` predicate accepts."""
    return _find[_Source[I].Element, _Source[I], C.Failure, C, _predicate_callable[_Source[I].Element, C]](predicate, _source(source^))


def any[I: Movable & Deinitable, C: BorrowCallable](predicate: C, var source: I
) raises C.Failure -> Bool where conforms_to(_Source[I].Element, Movable & Deinitable) and C.Payload == _Source[I].Element and C.Result == Bool:
    """Whether a `BorrowCallable` predicate accepts some element."""
    return _quantify[_Source[I].Element, _Source[I], C.Failure, C, _predicate_callable[_Source[I].Element, C]](predicate, _source(source^), True)


def all[I: Movable & Deinitable, C: BorrowCallable](predicate: C, var source: I
) raises C.Failure -> Bool where conforms_to(_Source[I].Element, Movable & Deinitable) and C.Payload == _Source[I].Element and C.Result == Bool:
    """Whether a `BorrowCallable` predicate accepts every element."""
    return _quantify[_Source[I].Element, _Source[I], C.Failure, C, _predicate_callable[_Source[I].Element, C]](predicate, _source(source^), False)
