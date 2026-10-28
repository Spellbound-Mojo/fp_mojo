"""Lazy adapters and terminal operations that the standard library does not provide.

A source is a native iterator or an owned collection (`IterableOwned`), which is
consumed. Lazy callbacks do not raise; `Result` is an ordinary element.
Standard `chain`, `zip`, `take` and the like stay in `std.iter` and
`std.itertools`.
"""

from fp.callables.products import _OptionalCell
from fp.callables._views import _UnaryViewable, _BorrowViewable
from fp.algebra.instances import _OptionalElement
from fp.callables._scan import _Carry
from ._callbacks import _snapshot_step
from fp.callables._predicates import _filter_decision
from std.iter import Iterator, IterableOwned, iter
from std.builtin.rebind import downcast, rebind_var
from fp.iteration._advance import _next_fused, _Source, _source
from fp.iteration._terminal import _find, _quantify, _collect_list
from fp.iteration._callbacks import _predicate_plain, _predicate_raising, _predicate_thin, _LazyUnary, _LazyStep, _apply_lazy_unary, _apply_lazy_step, _LazyPredicate, _LazyOptional, _apply_lazy_predicate, _apply_lazy_optional
from fp.callables.protocols import Unary, Binary
from fp.callables.protocols import BorrowCallable
from fp.iteration._callbacks import _predicate_callable


# Inline optional cells preserve native callback witnesses on Mojo 1.2. Each
# adapter initializes its cell once and borrows it mutably for every pull;
# ordinary native destruction still releases captures exactly once.
@fieldwise_init
struct _Map[T: Movable & Deinitable, U: Movable & Deinitable,
            I: Iterator, F: Movable & Deinitable = def(var T) thin -> U,
            apply: def(mut F, var T) thin -> U = _apply_lazy_unary[T, U, F]](Iterator, IterableOwned):
    comptime Element = Self.U
    comptime IteratorOwnedType = Self
    var _function: _OptionalCell[Self.F]
    var source: Self.I
    var done: Bool

    def __init__(out self, var function: Self.F, var source: Self.I, done: Bool):
        self._function = Optional(function^)
        self.source = source^
        self.done = done

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "map: source element type must match T"
        var item = _next_fused(self.source, self.done)
        var value = rebind_var[Self.T](item^)
        return Self.apply(self._function.value(), value^)

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
               F: Movable & Deinitable = def(T) thin -> Bool, inverted: Bool = False](Iterator, IterableOwned):
    comptime Element = Self.T
    comptime IteratorOwnedType = Self
    var _function: _OptionalCell[Self.F]
    var source: Self.I
    var done: Bool

    def __init__(out self, var function: Self.F, var source: Self.I, done: Bool):
        self._function = Optional(function^)
        self.source = source^
        self.done = done

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "filter: source element type must match T"
        while True:
            var item = _next_fused(self.source, self.done)
            var value = rebind_var[Self.T](item^)
            # Share the decision with eager filtering without wrapping an owned
            # native callback in a read-only BorrowCallable. Lazy invocation must
            # retain mutable access to captures (including at O3 on Mojo 1.1).
            if _filter_decision[Self.inverted](_apply_lazy_predicate[Self.T, Self.F](self._function.value(), value)):
                return value^

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


def filter_not[T: Movable & Deinitable, I: Movable & Deinitable, //](
    function: def(T) thin -> Bool, var source: I
) -> _Filter[T, _Source[I], def(T) thin -> Bool, True] where _Source[I].Element == T:
    """Lazily retain elements the borrowing predicate rejects.

    Construction pulls nothing. Each next call tests candidates once in source
    order until the predicate returns False. Retained values move unchanged;
    discarded values are destroyed. Exhaustion is fused, and abandoning the
    iterator destroys owned source and callback state without further calls.
    Callbacks cannot raise. Borrowed captures and source origins must remain
    alive and unmoved while used; move an owned closure in with callback^.

    Parameters:
        T: The element type, including origins.
        I: A native iterator or owned iterable, consumed without restarting it.

    Args:
        function: The borrowing Bool predicate, stored.
        source: The source, consumed.

    Returns:
        A FilterNotIterator of the original rejected elements, in source order.
    """
    return _Filter[T, _Source[I], def(T) thin -> Bool, True](function, _source(source^), False)


def filter_not[T: Movable & Deinitable, I: Movable & Deinitable, //, F: _LazyPredicate[T]](
    var function: F, var source: I
) -> _Filter[T, _Source[I], F, True] where _Source[I].Element == T:
    """Lazily retain rejected elements with a stored native closure."""
    return _Filter[T, _Source[I], F, True](function^, _source(source^), False)


def filter_not[I: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin](ref[o] predicate: C, var source: I
) -> _Filter[_Source[I].Element, _Source[I], C._BorrowView[o], True] where conforms_to(_Source[I].Element, Movable & Deinitable) and C._BorrowView[o].Payload == _Source[I].Element and C._BorrowView[o].Result == Bool and C._BorrowView[o].Failure == Never:
    """Retain a shared predicate until lazy filtering completes or is discarded."""
    return filter_not(predicate._borrow_view(), source^)


def filter_not[I: Movable & Deinitable, C: BorrowCallable](var predicate: C, var source: I
) -> _Filter[_Source[I].Element, _Source[I], C, True] where conforms_to(_Source[I].Element, Movable & Deinitable) and C.Payload == _Source[I].Element and C.Result == Bool and C.Failure == Never:
    """Lazily retain rejected elements with an owned library borrowing predicate."""
    return _Filter[_Source[I].Element, _Source[I], C, True](predicate^, _source(source^), False)


@fieldwise_init
struct _FilterMap[T: Movable & Deinitable, U: Movable & Deinitable,
                  I: Iterator, F: Movable & Deinitable = def(var T) thin -> Optional[U]](Iterator, IterableOwned):
    comptime Element = Self.U
    comptime IteratorOwnedType = Self
    var _function: _OptionalCell[Self.F]
    var source: Self.I
    var done: Bool

    def __init__(out self, var function: Self.F, var source: Self.I, done: Bool):
        self._function = Optional(function^)
        self.source = source^
        self.done = done

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "filter_map: source element type must match T"
        while True:
            var item = _next_fused(self.source, self.done)
            var value = rebind_var[Self.T](item^)
            var result = _apply_lazy_optional[Self.T, Self.U, Self.F](self._function.value(), value^)
            if result: return result.take()

def filter_map[T: Movable & Deinitable, U: Movable & Deinitable, I: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var T) thin -> R, var source: I
) -> _FilterMap[T, U, _Source[I], def(var T) thin -> R] where _Source[I].Element == T and R == Optional[U]:
    """Lazily apply `function` and keep the present results.

    Each element is moved into the function. Only `None` is skipped: a present
    `Result.Err` is an ordinary output.

    Parameters:
        T: The element type.
        U: The type of a present result.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        R: The callback result, checked against the required output type.

    Args:
        function: A plain function returning `Optional[U]`, stored.
        source: The source, consumed.

    Returns:
        A `FilterMapIterator`, a native iterator of the present results.
    """
    return _FilterMap[T, U, _Source[I], def(var T) thin -> R](function, _source(source^), False)


def filter_map[T: Movable & Deinitable, U: Movable & Deinitable, I: Movable & Deinitable, R: Movable & Deinitable, //,
               F: def(var T) -> R](var function: F, var source: I) -> _FilterMap[T, U, _Source[I], F] where _Source[I].Element == T and R == Optional[U]:
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


struct _ScanDriver[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable,
                   I: Iterator, F: Movable & Deinitable, initial_snapshot: Bool,
                   apply: def(mut F, var A, var T) thin -> Tuple[A,Y]](Iterator, IterableOwned):
    comptime Element = Self.Y
    comptime IteratorOwnedType = Self
    var _function: _OptionalCell[Self.F]
    var carry: _Carry[Self.A]
    var source: Self.I
    var started: Bool
    var done: Bool

    def __init__(out self, var function: Self.F, var initial: Self.A, var source: Self.I,
                 started: Bool, done: Bool):
        self._function = Optional(function^)
        self.carry = _Carry(initial^)
        self.source = source^
        self.started = started
        self.done = done

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.Element:
        comptime assert Self.I.Element == Self.T, "scan_left: source element type must match T" if Self.initial_snapshot else "scan_map: source element type must match T"
        if self.done: raise StopIteration()
        comptime if Self.initial_snapshot:
            comptime assert conforms_to(Self.A, Copyable) and Self.Y == Self.A
            if not self.started:
                self.started = True
                return rebind_var[Self.Y](self.carry.snapshot())
        var item = _next_fused(self.source, self.done)
        var pair = Self.apply(self._function.value(), self.carry.take(), rebind_var[Self.T](item^))
        return self.carry.replace(pair^)


comptime _Scan[A: Copyable & Deinitable, T: Movable & Deinitable, I: Iterator,
               F: Movable & Deinitable = def(var A, var T) thin -> A] = _ScanDriver[A,T,A,I,F,True,_snapshot_step[A,T,F]]


def scan_left[A: Copyable & Deinitable, T: Movable & Deinitable, I: Movable & Deinitable, R: Movable & Deinitable](
    function: def(var A, var T) thin -> R, var initial: A, var source: I
) -> _Scan[A, T, _Source[I], def(var A, var T) thin -> R] where _Source[I].Element == T and R == A:
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
        R: The callback result, checked against the required output type.

    Args:
        function: A plain function `(var A, var T) -> A`, stored.
        initial: The first accumulator, consumed.
        source: The source, consumed.

    Returns:
        A `ScanIterator`, a native iterator of the accumulator snapshots.
    """
    return _Scan[A, T, _Source[I], def(var A, var T) thin -> R](function, initial^, _source(source^), False, False)


def scan_left[A: Copyable & Deinitable, T: Movable & Deinitable, I: Movable & Deinitable, R: Movable & Deinitable, //,
              F: def(var A, var T) -> R](var function: F, var initial: A, var source: I) -> _Scan[A, T, _Source[I], F] where _Source[I].Element == T and R == A:
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


def find[P: Movable & Deinitable, I: Movable & Deinitable, //, F: def(P) -> Bool, T: Movable & Deinitable = P](
    predicate: F, var source: I
) -> Optional[T] where _Source[I].Element == T and P == T:
    """Return the first element `predicate` accepts, without pulling another.

    The predicate borrows each candidate; the accepted element is returned as
    it is, and rejected ones are destroyed.

    Parameters:
        P: The callback input, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The predicate's type: a plain function or a closure.
        T: The requested element type; defaults to P and must match it.

    Args:
        predicate: The predicate, borrowed.
        source: The source, consumed.

    Returns:
        The first accepted element, or `None` when there is none.
    """
    return rebind_var[Optional[T]](_find[P, _Source[I], Never, F, _predicate_plain[P, Bool, F]](predicate, _source(source^)))

def any[P: Movable & Deinitable, I: Movable & Deinitable, //, F: def(P) -> Bool, T: Movable & Deinitable = P](
    predicate: F, var source: I
) -> Bool where _Source[I].Element == T and P == T:
    """Whether `predicate` accepts some element; stops at the first accepted one.

    Parameters:
        P: The callback input, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The predicate's type: a plain function or a closure.
        T: The requested element type; defaults to P and must match it.

    Args:
        predicate: The predicate, borrowed; it borrows each candidate.
        source: The source, consumed.

    Returns:
        `True` at the first accepted element; `False` for an empty source.
    """
    return _quantify[P, _Source[I], Never, F, _predicate_plain[P, Bool, F]](predicate, _source(source^), True)


def all[P: Movable & Deinitable, I: Movable & Deinitable, //, F: def(P) -> Bool, T: Movable & Deinitable = P](
    predicate: F, var source: I
) -> Bool where _Source[I].Element == T and P == T:
    """Whether `predicate` accepts every element; stops at the first rejected one.

    Parameters:
        P: The callback input, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The predicate's type: a plain function or a closure.
        T: The requested element type; defaults to P and must match it.

    Args:
        predicate: The predicate, borrowed; it borrows each candidate.
        source: The source, consumed.

    Returns:
        `False` at the first rejected element; `True` for an empty source.
    """
    return _quantify[P, _Source[I], Never, F, _predicate_plain[P, Bool, F]](predicate, _source(source^), False)


def find[P: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
         F: def(P) raises E -> Bool, T: Movable & Deinitable = P](
    predicate: F, var source: I
) raises E -> Optional[T] where _Source[I].Element == T and P == T:
    """Return the first accepted element with a raising predicate; its error stops the search."""
    return rebind_var[Optional[T]](_find[P, _Source[I], E, F, _predicate_raising[P, E, Bool, F]](predicate, _source(source^)))

def any[P: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
         F: def(P) raises E -> Bool, T: Movable & Deinitable = P](
    predicate: F, var source: I
) raises E -> Bool where _Source[I].Element == T and P == T:
    """Whether a raising predicate accepts some element; its error stops the search."""
    return _quantify[P, _Source[I], E, F, _predicate_raising[P, E, Bool, F]](predicate, _source(source^), True)


def all[P: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
         F: def(P) raises E -> Bool, T: Movable & Deinitable = P](
    predicate: F, var source: I
) raises E -> Bool where _Source[I].Element == T and P == T:
    """Whether a raising predicate accepts every element; its error stops the search."""
    return _quantify[P, _Source[I], E, F, _predicate_raising[P, E, Bool, F]](predicate, _source(source^), False)


def find[P: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //, T: Movable & Deinitable = P](
    predicate: def(P) raises E thin -> Bool, var source: I
) raises E -> Optional[T] where _Source[I].Element == T and P == T:
    """Preserve a plain raising predicate's thin representation, including Never."""
    return rebind_var[Optional[T]](_find[P, _Source[I], E, def(P) raises E thin -> Bool, _predicate_thin[P, E]](predicate, _source(source^)))


def any[P: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //, T: Movable & Deinitable = P](
    predicate: def(P) raises E thin -> Bool, var source: I
) raises E -> Bool where _Source[I].Element == T and P == T:
    """Preserve a plain raising predicate's thin representation, including Never."""
    return _quantify[P, _Source[I], E, def(P) raises E thin -> Bool, _predicate_thin[P, E]](predicate, _source(source^), True)


def all[P: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //, T: Movable & Deinitable = P](
    predicate: def(P) raises E thin -> Bool, var source: I
) raises E -> Bool where _Source[I].Element == T and P == T:
    """Preserve a plain raising predicate's thin representation, including Never."""
    return _quantify[P, _Source[I], E, def(P) raises E thin -> Bool, _predicate_thin[P, E]](predicate, _source(source^), False)


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


comptime FilterNotIterator[T: Movable & Deinitable, I: Iterator, F: Movable & Deinitable = def(T) thin -> Bool] = _Filter[T, I, F, True]
"""The type filter_not returns, for a generic function's return annotation.

Parameters:
    T: The element type.
    I: The native iterator over the source.
    F: The predicate's type; the thin function type by default.
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
def map[I: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin](ref[o] function: F, var source: I
) -> _Map[F._View[o].Arg, F._View[o].Out, _Source[I], F._View[o]] where _Source[I].Element == F._View[o].Arg and F._View[o].Error == Never:
    """Retain a shared callable view in the lazy iterator."""
    return map(function._unary_view(), source^)


def map[I: Movable & Deinitable, F: Unary](var function: F, var source: I
) -> _Map[F.Arg, F.Out, _Source[I], F] where _Source[I].Element == F.Arg and F.Error == Never:
    """Lazily apply a library `Unary` value, such as a partial or a composition."""
    return _Map[F.Arg, F.Out, _Source[I], F](function^, _source(source^), False)


def filter_map[U: Movable & Deinitable, I: Movable & Deinitable, F: Unary](var function: F, var source: I
) -> _FilterMap[F.Arg, U, _Source[I], F] where _Source[I].Element == F.Arg and F.Out == Optional[U] and F.Error == Never:
    """Lazily apply a library `Unary` with an explicit Optional payload binding."""
    return _FilterMap[F.Arg, U, _Source[I], F](function^, _source(source^), False)


def filter_map[I: Movable & Deinitable, F: Unary, //](var function: F, var source: I
) -> _FilterMap[F.Arg, _OptionalElement[F.Out], _Source[I], F] where _Source[I].Element == F.Arg and F.Out == Optional[_OptionalElement[F.Out]] and F.Error == Never:
    """Infer the Optional payload and move a library callable into the iterator."""
    return filter_map[U=_OptionalElement[F.Out]](function^, source^)


def filter_map[I: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //,
               U: Movable & Deinitable = _OptionalElement[F._View[o].Out]](
    ref[o] function: F, var source: I
) -> _FilterMap[F._View[o].Arg, U, _Source[I], F._View[o]] where _Source[I].Element == F._View[o].Arg and F._View[o].Out == Optional[U] and F._View[o].Error == Never:
    """Infer the Optional payload and retain a shared callback until consumption."""
    return filter_map[U=U](function._unary_view(), source^)


def flat_map[I: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin](ref[o] function: F, var source: I
) -> _Flatten[_Map[F._View[o].Arg, F._View[o].Out, _Source[I], F._View[o]], F._View[o].Out] where _Source[I].Element == F._View[o].Arg and F._View[o].Error == Never:
    """Retain a shared callable view in the lazy iterator."""
    return flat_map(function._unary_view(), source^)


def flat_map[I: Movable & Deinitable, F: Unary](var function: F, var source: I
) -> _Flatten[_Map[F.Arg, F.Out, _Source[I], F], F.Out] where _Source[I].Element == F.Arg and F.Error == Never:
    """Lazily apply a library `Unary` value and concatenate the inner sources it returns."""
    return flatten(map(function^, source^))


def scan_left[A: Copyable & Deinitable, I: Movable & Deinitable, F: Binary](var function: F, var initial: A, var source: I
) -> _Scan[A, F.Second, _Source[I], F] where F.First == A and F.Second == _Source[I].Element and F.Out == A and F.Error == Never:
    """Lazily yield the snapshots of a scan with a library `Binary` step."""
    return _Scan[A, F.Second, _Source[I], F](function^, initial^, _source(source^), False, False)


def filter[I: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin](ref[o] predicate: C, var source: I
) -> _Filter[_Source[I].Element, _Source[I], C._BorrowView[o]] where conforms_to(_Source[I].Element, Movable & Deinitable) and C._BorrowView[o].Payload == _Source[I].Element and C._BorrowView[o].Result == Bool and C._BorrowView[o].Failure == Never:
    """Retain a shared predicate until lazy filtering completes or is discarded."""
    return filter(predicate._borrow_view(), source^)


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
