"""Consuming method chains over native iterators."""
from std.builtin.variadics import TypeList
from std.iter import _Enumerate, _ZipIterator, _ChainedIterator, enumerate as _std_enumerate
from std.itertools import take as _std_take, drop as _std_drop, take_while as _std_take_while, drop_while as _std_drop_while
from std.itertools.itertools import _TakeIterator, _DropIterator, _TakeWhileIterator, _DropWhileIterator
from fp.iteration._native import _OwnedSource, _NativeSources, _NativeTail, _SameSource, _native_zip, _native_chain
from fp.iteration.indexed import ZipWithIterator, IndexedMapIterator, zip_with as _zip_with, map_with_index as _map_with_index
from fp.iteration.prefixes import TakeWhileIterator, DropWhileIterator, take_while as _take_while, drop_while as _drop_while
from fp.iteration._callbacks import _LazyPredicate, _IndexedBinary
from fp.iteration.terminals import first as _first, last as _last, is_empty as _is_empty, count as _count, contains as _contains, to_non_empty_list as _to_non_empty_list, combine_all_optional as _combine_all_optional, _count_where, _for_each, _collect_fold
from fp.data.non_empty_list import NonEmptyList
from fp.algebra.validation import ValidationFamily, _ListErrors
from fp.algebra._sequencing import _EffectRetain
from fp.iteration._sequencing import _IteratorMap, _bind_iterator
from fp.callables._transforms import _IgnoreInput, _BorrowedUnary
from fp.callables.protocols import ThunkContract
from fp.callables.native import _NativeBorrowMut, _Thunk
from fp.algebra.protocols import Semigroup
from fp.algebra._admission import _CarrierCompatible, _CollectCompatible
from fp.algebra._effect_combinators import _AllLive, _BoolLive, _PredicateStep, _EffectFold, _fold_effect
from fp.algebra.protocols import Monad
from fp.algebra.operations import _EntryError, _InferError
from fp.data._result import _ResultType
from fp.callables._views import _UnaryViewable
from fp.callables.protocols import BinaryContract
from fp.callables.invoke import RepeatableBinary
from fp.callables.native import _Binary, _RaisingBinary, _NativeBinaryRef
from std.builtin.rebind import rebind_var

from fp.algebra.instances import _ListElement

from fp.algebra._traversal import _FlattenAfter, _CompactAfter, _traverse_then, _Discard, _TraverseTap, _traverse_void, _traverse_as, _EffectVoid
from fp.callables.protocols import BorrowCallContract

from fp.functions.composition import Identity as _Same
from fp.callables.native import _Unary, _RaisingUnary, _NativeUnaryRef, _Borrowing, _RaisingBorrowing, _NativeBorrowRef
from fp.iteration.reductions import _fold_map, _find_map, _extremum, _IntSum, _SIMDSum
from fp.algebra.protocols import Monoid
from fp._internal.errors import _CommonError, _ErrorCompatible
from fp.callables.protocols import UnaryContract
from std.builtin.rebind import downcast
from fp.callables._transforms import _Fill, _Replace, _TupleWith, _Observe, _ObserveNative
from fp.iteration.adapters import _Map, _FilterMap
from fp.iteration.derived import compact as _derived_compact
from fp.algebra.instances import ListFamily
from fp.algebra.protocols import Applicative
from fp.iteration.derived import fill as _derived_fill
from fp.iteration.derived import replace as _derived_replace
from fp.iteration.derived import void as _derived_void
from fp.iteration.derived import tuple_left as _derived_tuple_left
from fp.iteration.derived import tuple_right as _derived_tuple_right
from fp.iteration.derived import pair_with as _derived_pair_with
from fp.iteration.derived import tap_each as _derived_tap_each
from std.iter import Iterator, IterableOwned
from fp.callables.protocols import Unary, Binary, BorrowCallable
from fp.data.control import ControlFlow
from fp.iteration._advance import _Source, _source
from fp.iteration.adapters import (
    MapIterator,
    FilterIterator,
    FilterNotIterator,
    FilterMapIterator,
    FlatMapIterator,
    ScanIterator,
    _Flatten,
    map as _map,
    filter as _filter,
    filter_not as _filter_not,
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

    # --- iterator expansion syntax (generated) ---
    # Generated by scripts/generate_plain_overloads.py; algorithms live in the operation owners.

    def take(deinit self, n: Int) -> Iter[_TakeIterator[Self.I]]:
        """Apply native take without restarting the source.

        Construction pulls nothing; non-positive counts retain standard semantics.
        Bounds and exhaustion delegate unchanged to the native adapter.

        Args:
            n: The native take/drop count; non-positive counts retain standard behavior.

        Returns:
            Iter[_TakeIterator[Self.I]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_std_take(_OwnedSource(self._iterator^), n))

    def drop(deinit self, n: Int) -> Iter[_DropIterator[Self.I]] where conforms_to(Self.I.Element, Deinitable):
        """Apply native drop without restarting the source.

        Construction pulls nothing; non-positive counts retain standard semantics.
        Bounds and exhaustion delegate unchanged to the native adapter.

        Args:
            n: The native take/drop count; non-positive counts retain standard behavior.

        Returns:
            Iter[_DropIterator[Self.I]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_std_drop(_OwnedSource(self._iterator^), n))

    def enumerate(deinit self, *, start: Int = 0) -> Iter[_Enumerate[Self.I]]:
        """Lazily attach native (index, value) pairs, starting at start.

        The source keeps its current position; construction pulls nothing.
        Bounds and exhaustion remain native.

        Args:
            start: The first native Int index; defaults to zero.

        Returns:
            Iter[_Enumerate[Self.I]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_std_enumerate(_OwnedSource(self._iterator^), start=start))

    def zip[*Ss: Movable & Deinitable](deinit self, var *others: *Ss) -> Iter[_ZipIterator[MutUntrackedOrigin, *_NativeTail[Self.I, *Ss]]]:
        """Combine the remaining sources through native zip.

        Sources are consumed once and never restarted. Zip yields flat tuples,
        stopping at the shortest input; earlier inputs may be pulled before a later
        input ends. Chain yields same-typed elements in source order. Construction
        pulls nothing; native bounds, ownership and exhaustion remain unchanged.

        Parameters:
            Ss: The additional source types; an iterator keeps its current position.

        Args:
            others: Additional sources, consumed without restarting iterators.

        Returns:
            Iter[_ZipIterator[MutUntrackedOrigin, *_NativeTail[Self.I, *Ss]]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_native_zip(self._iterator^, *others^))

    def chain[*Ss: Movable & Deinitable](deinit self, var *others: *Ss) -> Iter[_ChainedIterator[*_NativeTail[Self.I, *Ss]]] where TypeList[Trait=Movable & Deinitable, Ss.values]().all[_SameSource[Self.I.Element, _]]():
        """Combine the remaining sources through native chain.

        Sources are consumed once and never restarted. Zip yields flat tuples,
        stopping at the shortest input; earlier inputs may be pulled before a later
        input ends. Chain yields same-typed elements in source order. Construction
        pulls nothing; native bounds, ownership and exhaustion remain unchanged.

        Parameters:
            Ss: The additional source types; an iterator keeps its current position.

        Args:
            others: Additional sources, consumed without restarting iterators.

        Returns:
            Iter[_ChainedIterator[*_NativeTail[Self.I, *Ss]]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_native_chain(self._iterator^, *others^))

    def take_while[predicate: def(Self.I.Element) thin -> Bool](deinit self) -> Iter[_TakeWhileIterator[InnerIteratorType=Self.I, predicate=predicate]] where conforms_to(Self.I.Element, Deinitable):
        """Apply native take_while with a compile-time thin predicate.

        Construction pulls nothing. Take consumes the first rejected candidate;
        drop yields it and stops testing. Bounds and exhaustion remain native.
        Use the value-taking overload for an owned closure or library predicate.

        Parameters:
            predicate: The non-raising compile-time thin predicate.

        Returns:
            Iter[_TakeWhileIterator[InnerIteratorType=Self.I, predicate=predicate]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_std_take_while[predicate=predicate](_OwnedSource(self._iterator^)))

    def drop_while[predicate: def(Self.I.Element) thin -> Bool](deinit self) -> Iter[_DropWhileIterator[InnerIteratorType=Self.I, predicate=predicate]] where conforms_to(Self.I.Element, Deinitable):
        """Apply native drop_while with a compile-time thin predicate.

        Construction pulls nothing. Take consumes the first rejected candidate;
        drop yields it and stops testing. Bounds and exhaustion remain native.
        Use the value-taking overload for an owned closure or library predicate.

        Parameters:
            predicate: The non-raising compile-time thin predicate.

        Returns:
            Iter[_DropWhileIterator[InnerIteratorType=Self.I, predicate=predicate]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_std_drop_while[predicate=predicate](_OwnedSource(self._iterator^)))

    def zip_with[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, W: Movable & Deinitable](deinit self, var other: W, var function: def(var A, var B) thin -> R) -> Iter[ZipWithIterator[A, B, R, Self.I, _Source[W], def(var A, var B) thin -> R]] where Self.I.Element == A and _Source[W].Element == B:
        """Lazily combine pairs using native left-to-right zip followed by map.

        Construction is inert; each output moves its inputs into the non-raising callback.
        Native zip can consume an earlier input before a later one ends.
        Mapping fuses exhaustion and retains owned captures, move-only results and native origins.

        Parameters:
            A: The first callback argument type.
            B: The second callback argument type.
            R: The callback result type.
            W: The second consumed source type.

        Args:
            other: The second source, consumed at its current position.
            function: The callback; lazy operations own it and terminals borrow native callbacks or consume library callables.

        Returns:
            Iter[ZipWithIterator[A, B, R, Self.I, _Source[W], def(var A, var B) thin -> R]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_zip_with(function, self._iterator^, other^))

    def zip_with[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, W: Movable & Deinitable, //, F: _Binary[A, B, R]](deinit self, var other: W, var function: F) -> Iter[ZipWithIterator[A, B, R, Self.I, _Source[W], F]] where Self.I.Element == A and _Source[W].Element == B:
        """Lazily combine pairs using native left-to-right zip followed by map.
        """
        return Iter(_zip_with(function^, self._iterator^, other^))

    def zip_with[F: BinaryContract & Movable & Deinitable, W: Movable & Deinitable](deinit self, var other: W, var function: F) -> Iter[ZipWithIterator[F.First, F.Second, F.Out, Self.I, _Source[W], F]] where Self.I.Element == F.First and _Source[W].Element == F.Second and F.Error == Never and RepeatableBinary[F]:
        """Lazily combine pairs using native left-to-right zip followed by map.
        """
        return Iter(_zip_with(function^, self._iterator^, other^))

    def map_with_index[T: Movable & Deinitable, R: Movable & Deinitable](deinit self, var function: def(var Int, var T) thin -> R, *, start: Int = 0) -> Iter[IndexedMapIterator[T, R, Self.I, def(var Int, var T) thin -> R]] where Self.I.Element == T:
        """Lazily map (index, owned element), using native enumerate then map.

        Construction is inert; each output moves its inputs into the non-raising callback.
        Mapping fuses exhaustion and retains owned captures, move-only results and native origins.

        Parameters:
            T: The source element type, including origins.
            R: The callback result type.

        Args:
            function: The callback; lazy operations own it and terminals borrow native callbacks or consume library callables.
            start: The first native Int index; defaults to zero.

        Returns:
            Iter[IndexedMapIterator[T, R, Self.I, def(var Int, var T) thin -> R]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_map_with_index(function, self._iterator^, start=start))

    def map_with_index[T: Movable & Deinitable, R: Movable & Deinitable, //, F: _IndexedBinary[T, R]](deinit self, var function: F, *, start: Int = 0) -> Iter[IndexedMapIterator[T, R, Self.I, F]] where Self.I.Element == T:
        """Lazily map (index, owned element), using native enumerate then map.
        """
        return Iter(_map_with_index(function^, self._iterator^, start=start))

    def map_with_index[F: BinaryContract & Movable & Deinitable](deinit self, var function: F, *, start: Int = 0) -> Iter[IndexedMapIterator[F.Second, F.Out, Self.I, F]] where Self.I.Element == F.Second and F.Error == Never and RepeatableBinary[F] and F.First == Int:
        """Lazily map (index, owned element), using native enumerate then map.
        """
        return Iter(_map_with_index(function^, self._iterator^, start=start))

    def take_while[T: Movable & Deinitable](deinit self, var predicate: def(T) thin -> Bool) -> Iter[TakeWhileIterator[T, Self.I, def(T) thin -> Bool]] where Self.I.Element == T:
        """Yield the initial matching prefix; consume and discard its first rejection.

        Construction pulls nothing. The stored predicate borrows each candidate and cannot raise.
        Exhaustion is fused; abandonment releases captures and the unconsumed source.
        Uses constant state and preserves move-only elements and embedded origins.

        Parameters:
            T: The source element type, including origins.

        Args:
            predicate: The predicate, borrowing each candidate; lazy operations own it and terminals borrow native callbacks or consume library callables.

        Returns:
            Iter[TakeWhileIterator[T, Self.I, def(T) thin -> Bool]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_take_while(predicate, self._iterator^))

    def take_while[T: Movable & Deinitable, //, F: _LazyPredicate[T]](deinit self, var predicate: F) -> Iter[TakeWhileIterator[T, Self.I, F]] where Self.I.Element == T:
        """Yield the initial matching prefix; consume and discard its first rejection.
        """
        return Iter(_take_while(predicate^, self._iterator^))

    def take_while[C: BorrowCallable](deinit self, var predicate: C) -> Iter[TakeWhileIterator[downcast[C.Payload, Movable & Deinitable], Self.I, C]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool and C.Failure == Never:
        """Yield the initial matching prefix; consume and discard its first rejection.
        """
        return Iter(_take_while(predicate^, self._iterator^))

    def drop_while[T: Movable & Deinitable](deinit self, var predicate: def(T) thin -> Bool) -> Iter[DropWhileIterator[T, Self.I, def(T) thin -> Bool]] where Self.I.Element == T:
        """Discard the matching prefix; yield the first rejection and stop testing.

        Construction pulls nothing. The stored predicate borrows each candidate and cannot raise.
        Exhaustion is fused; abandonment releases captures and the unconsumed source.
        Uses constant state and preserves move-only elements and embedded origins.

        Parameters:
            T: The source element type, including origins.

        Args:
            predicate: The predicate, borrowing each candidate; lazy operations own it and terminals borrow native callbacks or consume library callables.

        Returns:
            Iter[DropWhileIterator[T, Self.I, def(T) thin -> Bool]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_drop_while(predicate, self._iterator^))

    def drop_while[T: Movable & Deinitable, //, F: _LazyPredicate[T]](deinit self, var predicate: F) -> Iter[DropWhileIterator[T, Self.I, F]] where Self.I.Element == T:
        """Discard the matching prefix; yield the first rejection and stop testing.
        """
        return Iter(_drop_while(predicate^, self._iterator^))

    def drop_while[C: BorrowCallable](deinit self, var predicate: C) -> Iter[DropWhileIterator[downcast[C.Payload, Movable & Deinitable], Self.I, C]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool and C.Failure == Never:
        """Discard the matching prefix; yield the first rejection and stop testing.
        """
        return Iter(_drop_while(predicate^, self._iterator^))

    def first(deinit self) -> Optional[downcast[Self.I.Element, Movable & Deinitable]] where conforms_to(Self.I.Element, Deinitable):
        """Consume at most one element and return it, or None for empty input.

        The source is consumed without restarting. Values are moved or destroyed
        without requiring copies. Early exit destroys the unconsumed owner; no
        additional value is pulled. Collection and full reductions require finite
        input; count visits every element even when bounds give its length.

        Returns:
            Optional[downcast[Self.I.Element, Movable & Deinitable]] with the ownership, timing and empty-input behavior described above.
        """
        return _first(self._iterator^)

    def last(deinit self) -> Optional[downcast[Self.I.Element, Movable & Deinitable]] where conforms_to(Self.I.Element, Deinitable):
        """Consume every remaining element and return the last, or None.

        The source is consumed without restarting. Values are moved or destroyed
        without requiring copies. Early exit destroys the unconsumed owner; no
        additional value is pulled. Collection and full reductions require finite
        input; count visits every element even when bounds give its length.

        Returns:
            Optional[downcast[Self.I.Element, Movable & Deinitable]] with the ownership, timing and empty-input behavior described above.
        """
        return _last(self._iterator^)

    def is_empty(deinit self) -> Bool where conforms_to(Self.I.Element, Deinitable):
        """Consume at most one element and report whether none was present.

        The source is consumed without restarting. Values are moved or destroyed
        without requiring copies. Early exit destroys the unconsumed owner; no
        additional value is pulled. Collection and full reductions require finite
        input; count visits every element even when bounds give its length.

        Returns:
            Bool with the ownership, timing and empty-input behavior described above.
        """
        return _is_empty(self._iterator^)

    def count(deinit self) -> Int where conforms_to(Self.I.Element, Deinitable):
        """Consume and count every remaining element; empty input returns zero.

        The source is consumed without restarting. Values are moved or destroyed
        without requiring copies. Early exit destroys the unconsumed owner; no
        additional value is pulled. Collection and full reductions require finite
        input; count visits every element even when bounds give its length.

        Returns:
            Int with the ownership, timing and empty-input behavior described above.
        """
        return _count(self._iterator^)

    def contains[T: Equatable & Movable & Deinitable, o: ImmOrigin](deinit self, ref[o] value: T) -> Bool where Self.I.Element == T and conforms_to(Self.I.Element, Movable & Deinitable):
        """Borrow candidates for native equality and stop at the first match.

        The source is consumed without restarting. Values are moved or destroyed
        without requiring copies. Early exit destroys the unconsumed owner; no
        additional value is pulled. Collection and full reductions require finite
        input; count visits every element even when bounds give its length.

        Parameters:
            T: The source element type, including origins.
            o: The origin of the borrowed callback or comparison value.

        Args:
            value: The comparison value, borrowed for the duration of the terminal.

        Returns:
            Bool with the ownership, timing and empty-input behavior described above.
        """
        return _contains(self._iterator^, value)

    def to_non_empty_list(deinit self) -> Optional[NonEmptyList[downcast[Self.I.Element, Movable & Deinitable]]] where conforms_to(Self.I.Element, Deinitable):
        """Collect once into a checked NonEmptyList, returning None when empty.

        The source is consumed without restarting. Values are moved or destroyed
        without requiring copies. Early exit destroys the unconsumed owner; no
        additional value is pulled. Collection and full reductions require finite
        input; count visits every element even when bounds give its length.

        Returns:
            Optional[NonEmptyList[downcast[Self.I.Element, Movable & Deinitable]]] with the ownership, timing and empty-input behavior described above.
        """
        return _to_non_empty_list(self._iterator^)

    def combine_all_optional[S: Semigroup](deinit self) raises S.Error -> Optional[S.Value] where Self.I.Element == S.Value:
        """Combine left to right with a Semigroup; empty input returns None.

        The source is consumed without restarting. Values are moved or destroyed
        without requiring copies. Early exit destroys the unconsumed owner; no
        additional value is pulled. Collection and full reductions require finite
        input; count visits every element even when bounds give its length.

        Parameters:
            S: The explicit Semigroup; no identity value is required.

        Returns:
            Optional[S.Value] with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _combine_all_optional[S=S](self._iterator^)

    def count_where[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] predicate: F) raises Never -> Int where Self.I.Element == downcast[P, Movable & Deinitable] and R == Bool:
        """Count accepted candidates, borrowing each once; empty input returns zero.

        This is a consuming terminal. Native callbacks are borrowed in place;
        library callbacks are consumed. Failure stops before the next pull and
        keeps its exact native type, including callback StopIteration. Move-only
        inputs and results retain their origins; no intermediate collection is built.

        Parameters:
            P: The admitted type parameter.
            R: The callback result type.
            o: The origin of the borrowed callback or comparison value.
            F: The concrete callback type, preserving captures and receiver semantics.

        Args:
            predicate: The predicate, borrowing each candidate; lazy operations own it and terminals borrow native callbacks or consume library callables.

        Returns:
            Int with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _count_where(_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=predicate)), self._iterator^)

    def count_where[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] predicate: F) raises E -> Int where Self.I.Element == downcast[P, Movable & Deinitable] and R == Bool:
        """Count accepted candidates, borrowing each once; empty input returns zero.
        """
        return _count_where(_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=predicate)), self._iterator^)

    def count_where[C: BorrowCallable](deinit self, var predicate: C) raises C.Failure -> Int where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool:
        """Count accepted candidates, borrowing each once; empty input returns zero.
        """
        return _count_where(predicate^, self._iterator^)

    def for_each[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> NoneType where Self.I.Element == A and R == NoneType:
        """Move each element into a callback returning NoneType, then return None.

        This is a consuming terminal. Native callbacks are borrowed in place;
        library callbacks are consumed. Failure stops before the next pull and
        keeps its exact native type, including callback StopIteration. Move-only
        inputs and results retain their origins; no intermediate collection is built.

        Parameters:
            A: The first callback argument type.
            R: The callback result type.
            o: The origin of the borrowed callback or comparison value.
            F: The concrete callback type, preserving captures and receiver semantics.

        Args:
            function: The callback; lazy operations own it and terminals borrow native callbacks or consume library callables.

        Returns:
            NoneType with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _for_each(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def for_each[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> NoneType where Self.I.Element == A and R == NoneType:
        """Move each element into a callback returning NoneType, then return None.
        """
        return _for_each(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def for_each[F: UnaryContract & Movable & Deinitable](deinit self, var function: F) raises F.Error -> NoneType where Self.I.Element == F.Arg and F.Out == NoneType:
        """Move each element into a callback returning NoneType, then return None.
        """
        return _for_each(function^, self._iterator^)

    def collect_fold[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises M.Error -> M.Value where Self.I.Element == A and R == Optional[M.Value]:
        """Map to Optional monoid values, skip absence and combine present values in order.

        This is a consuming terminal. Native callbacks are borrowed in place;
        library callbacks are consumed. Failure stops before the next pull and
        keeps its exact native type, including callback StopIteration. Move-only
        inputs and results retain their origins; no intermediate collection is built.

        Parameters:
            A: The first callback argument type.
            R: The callback result type.
            o: The origin of the borrowed callback or comparison value.
            M: The explicit Monoid; identity and combination retain its error type.
            F: The concrete callback type, preserving captures and receiver semantics.

        Args:
            function: The callback; lazy operations own it and terminals borrow native callbacks or consume library callables.

        Returns:
            M.Value with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _collect_fold[M=M, E=M.Error](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def collect_fold[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> M.Value where Self.I.Element == A and R == Optional[M.Value] and _ErrorCompatible[E, M.Error]:
        """Map to Optional monoid values, skip absence and combine present values in order.
        """
        return _collect_fold[M=M, E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def collect_fold[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> M.Value where Self.I.Element == F.Arg and F.Out == Optional[M.Value]:
        """Map to Optional monoid values, skip absence and combine present values in order.
        """
        return _collect_fold[M=M, E=_CommonError[F.Error, M.Error]](function^, self._iterator^)
    # --- end iterator expansion syntax ---

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

    def map[F: _UnaryViewable, o: ImmOrigin](deinit self, ref[o] function: F
    ) -> Iter[MapIterator[F._View[o].Arg, F._View[o].Out, Self.I, F._View[o]]] where Self.I.Element == F._View[o].Arg and F._View[o].Error == Never:
        """Retain a shared callable view in the lazy pipeline."""
        return Iter(_map(function._unary_view(), self._iterator^))

    def map[F: Unary](deinit self, var function: F
    ) -> Iter[MapIterator[F.Arg, F.Out, Self.I, F]] where Self.I.Element == F.Arg and F.Error == Never:
        """Lazily transform each element with a library `Unary` value."""
        return Iter(_map(function^, self._iterator^))


    def fill[T: Movable & Deinitable, U: Copyable & Deinitable](deinit self, var value: U
    ) -> Iter[_Map[T, U, Self.I, _Fill[T, U]]] where Self.I.Element == T:
        """Copy value into every payload position. Evaluation is lazy.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.

        Args:
            value: The constant, consumed and copied once per emitted payload.

        Returns:
            The source shape with a copy of value at each payload position; empty input stays empty.
        """
        return Iter(_derived_fill[T=T](value^, self._iterator^))

    def replace[T: Copyable & Equatable & Deinitable](deinit self, var old: T, var new: T
    ) -> Iter[_Map[T, T, Self.I, _Replace[T]]] where Self.I.Element == T:
        """Replace equal payloads, moving unmatched values unchanged. Evaluation is lazy.

        Parameters:
            T: The element type, including its native origins.

        Args:
            old: The value to compare against each payload, consumed.
            new: The replacement, consumed and copied only for matching payloads.

        Returns:
            The source shape with matching elements replaced and unmatched elements moved unchanged.
        """
        return Iter(_derived_replace[T=T](old^, new^, self._iterator^))

    def void[T: Movable & Deinitable](deinit self
    ) -> Iter[_Map[T, NoneType, Self.I, _Fill[T, NoneType]]] where Self.I.Element == T:
        """Discard payloads while preserving their container shape. Evaluation is lazy.

        Parameters:
            T: The element type, including its native origins.

        Returns:
            The source shape with NoneType payloads; a lazy iterator is not drained.
        """
        return Iter(_derived_void[T=T](self._iterator^))

    def tuple_left[T: Movable & Deinitable, U: Copyable & Deinitable](deinit self, var value: U
    ) -> Iter[_Map[T, Tuple[U, T], Self.I, _TupleWith[T, U, True]]] where Self.I.Element == T:
        """Pair each payload with a copy of value on the left. Evaluation is lazy.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.

        Args:
            value: The constant, consumed and copied once per emitted payload.

        Returns:
            The source shape containing a copied constant followed by each original element.
        """
        return Iter(_derived_tuple_left[T=T](value^, self._iterator^))

    def tuple_right[T: Movable & Deinitable, U: Copyable & Deinitable](deinit self, var value: U
    ) -> Iter[_Map[T, Tuple[T, U], Self.I, _TupleWith[T, U, False]]] where Self.I.Element == T:
        """Pair each payload with a copy of value on the right. Evaluation is lazy.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.

        Args:
            value: The constant, consumed and copied once per emitted payload.

        Returns:
            The source shape containing each original element followed by a copied constant.
        """
        return Iter(_derived_tuple_right[T=T](value^, self._iterator^))

    def pair_with[P: AnyType, R: Movable & Deinitable, //, F: _Borrowing[P, R]](deinit self, var function: F
    ) -> Iter[_Map[downcast[P, Movable & Deinitable], Tuple[downcast[P, Movable & Deinitable], R], Self.I, _ObserveNative[P, R, F, True]]] where Self.I.Element == downcast[P, Movable & Deinitable]:
        """Borrow each element and pair it with its projection. Evaluation is lazy.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The source shape containing each original element beside its borrowed projection.
        """
        return Iter(_derived_pair_with[P=P](function^, self._iterator^))

    def pair_with[T: Movable & Deinitable, C: BorrowCallable](deinit self, var function: C
    ) -> Iter[_Map[T, Tuple[T, C.Result], Self.I, _Observe[T, C, True]]] where Self.I.Element == T and C.Payload == T and C.Failure == Never:
        """Borrow each element and pair it with its projection. Evaluation is lazy."""
        return Iter(_derived_pair_with[T=T](function^, self._iterator^))

    def tap_each[P: AnyType, R: Movable & Deinitable, //, F: _Borrowing[P, R]](deinit self, var function: F
    ) -> Iter[_Map[downcast[P, Movable & Deinitable], downcast[P, Movable & Deinitable], Self.I, _ObserveNative[P, R, F, False]]] where Self.I.Element == downcast[P, Movable & Deinitable]:
        """Borrow each element and inspect it without changing it. Evaluation is lazy.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The original elements after inspection; callback results are discarded.
        """
        return Iter(_derived_tap_each[P=P](function^, self._iterator^))

    def tap_each[T: Movable & Deinitable, C: BorrowCallable](deinit self, var function: C
    ) -> Iter[_Map[T, T, Self.I, _Observe[T, C, False]]] where Self.I.Element == T and C.Payload == T and C.Failure == Never:
        """Borrow each element and inspect it without changing it. Evaluation is lazy."""
        return Iter(_derived_tap_each[T=T](function^, self._iterator^))

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

    def filter_not[T: Movable & Deinitable](
        deinit self, predicate: def(T) thin -> Bool
    ) -> Iter[FilterNotIterator[T, Self.I]] where Self.I.Element == T:
        """Lazily retain original elements the borrowing predicate rejects.

        Calls run only as elements are pulled. Each candidate is borrowed once;
        retained values move unchanged. Plain functions, stored closures and
        non-raising BorrowCallable values are supported, as with filter.

        Parameters:
            T: The source element type.

        Args:
            predicate: The non-raising borrowing predicate, stored.

        Returns:
            An Iter over rejected elements, in source order.
        """
        return Iter(_filter_not(predicate, self._iterator^))

    def filter_not[T: Movable & Deinitable, //, F: def(T) -> Bool](
        deinit self, var predicate: F
    ) -> Iter[FilterNotIterator[T, Self.I, F]] where Self.I.Element == T:
        """Lazily retain rejected elements with a stored native closure."""
        return Iter(_filter_not(predicate^, self._iterator^))

    def filter_not[C: BorrowCallable](deinit self, var predicate: C
    ) -> Iter[FilterNotIterator[Self.I.Element, Self.I, C]] where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool and C.Failure == Never:
        """Lazily retain rejected elements with an owned library predicate."""
        return Iter(_filter_not(predicate^, self._iterator^))

    def compact[T: Movable & Deinitable](deinit self
    ) -> Iter[_FilterMap[Optional[T], T, Self.I, _Same[Optional[T]]]] where Self.I.Element == Optional[T]:
        """Lazily unwrap present Optional elements and discard absent ones.

        Parameters:
            T: The element type, including its native origins.

        Returns:
            The carrier of unwrapped present Optional payloads, in source order.
        """
        return Iter(_derived_compact[T=T](self._iterator^))

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

    def flat_map[F: _UnaryViewable, o: ImmOrigin](deinit self, ref[o] function: F
    ) -> Iter[FlatMapIterator[F._View[o].Arg, F._View[o].Out, Self.I, F._View[o]]] where Self.I.Element == F._View[o].Arg and F._View[o].Error == Never:
        """Retain a shared callable view in the lazy pipeline."""
        return Iter(_flat_map(function._unary_view(), self._iterator^))

    def flat_map[F: Unary](deinit self, var function: F
    ) -> Iter[FlatMapIterator[F.Arg, F.Out, Self.I, F]] where Self.I.Element == F.Arg and F.Error == Never:
        """Lazily expand elements with a library `Unary` value."""
        return Iter(_flat_map(function^, self._iterator^))

    # --- sequencing conveniences (generated) ---
    # Generated by scripts/generate_sequencing_syntax.py; execution stays in shared continuations.

    def flat_tap[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, C].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, C]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and C.Payload == downcast[Self.I.Element, Movable & Deinitable] and C.Failure == Never:
        """Sequence a borrowing effectful callback and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A lazy iterator over the sequenced outputs; construction pulls nothing.

        Raises:
            Never; lazy callbacks must not raise.
        """
        return Iter(_bind_iterator(_EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, C](function^), self._iterator^))

    def flat_tap[P: AnyType, R: Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False]].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and P == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
        """Sequence a borrowing effectful callback and retain each original value."""
        return Iter(_bind_iterator(_EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False]](_NativeBorrowMut[P, R, C, False](function^)), self._iterator^))

    def flat_pair_with[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, C, False, True].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, C, False, True]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and C.Payload == downcast[Self.I.Element, Movable & Deinitable] and C.Failure == Never:
        """Sequence a borrowing effectful projection and pair each success with its original.

        Each successful projection emits (original, projected). Projected values
        are moved; only retained originals need Copyable when effects branch.


        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A lazy iterator over the sequenced outputs; construction pulls nothing.

        Raises:
            Never; lazy callbacks must not raise.
        """
        return Iter(_bind_iterator(_EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, C, False, True](function^), self._iterator^))

    def flat_pair_with[P: AnyType, R: Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False], False, True].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False], False, True]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and P == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        return Iter(_bind_iterator(_EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False], False, True](_NativeBorrowMut[P, R, C, False](function^)), self._iterator^))

    def followed_by[C: ThunkContract & Movable & Deinitable, //](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C]].Out, Self.I, _BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and C.Error == Never:
        """Sequence a zero-argument factory and keep its produced values.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A lazy iterator over the sequenced outputs; construction pulls nothing.

        Raises:
            Never; lazy callbacks must not raise.
        """
        return Iter(_bind_iterator(_BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C]](_IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C](function^)), self._iterator^))

    def followed_by[R: Movable & Deinitable, //, C: _Thunk[R]](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]].Out, Self.I, _BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
        """Sequence a zero-argument factory and keep its produced values."""
        return Iter(_bind_iterator(_BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]](_NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True](function^)), self._iterator^))

    def before[C: ThunkContract & Movable & Deinitable, //](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C]].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and C.Error == Never:
        """Sequence a zero-argument factory and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A lazy iterator over the sequenced outputs; construction pulls nothing.

        Raises:
            Never; lazy callbacks must not raise.
        """
        return Iter(_bind_iterator(_EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C]](_IgnoreInput[downcast[Self.I.Element, Movable & Deinitable], C](function^)), self._iterator^))

    def before[R: Movable & Deinitable, //, C: _Thunk[R]](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
        """Sequence a zero-argument factory and retain each original value."""
        return Iter(_bind_iterator(_EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]](_NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True](function^)), self._iterator^))
    # --- end sequencing conveniences ---

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

    # --- traversal conveniences (generated) ---
    # Generated by scripts/generate_traversal_syntax.py; execution stays in algebra._traversal and families.

    def traverse_void[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, G._LoopError[Self.I, F, _Discard[G.Element[F.Out]]]] -> G._Looped[Self.I, F, _Discard[G.Element[F.Out]]] where _Source[Self.I].Element == F.Arg and _CarrierCompatible[G, F.Out]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_void[Self.I, F, G, _EntryError[X, G._LoopError[Self.I, F, _Discard[G.Element[F.Out]]]]](function^, self._iterator^)

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> G._Looped[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]] where _Source[Self.I].Element == A and _CarrierCompatible[G, R]:
        """Traverse effects without retaining successful outputs."""
        return _traverse_void[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Self.I, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> G._Looped[Self.I, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]] where _Source[Self.I].Element == A and _CarrierCompatible[G, R]:
        """Traverse effects without retaining successful outputs."""
        return _traverse_void[Self.I, _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[Self.I, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def traverse_tap[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] -> G.Collected[Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]] where _Source[Self.I].Element == downcast[C.Payload, Movable & Deinitable] and _CarrierCompatible[G, C.Result]:
        """Traverse effects and retain the original payloads on success.

        Parameters:
            C: The borrowing library callback type.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the original payloads; Piped preserves source shape and Iter/direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_as[ListFamily, G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C], _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C](function^), self._iterator^)

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] -> G.Collected[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _CarrierCompatible[G, R]:
        """Traverse effects and retain the original payloads on success."""
        return _traverse_as[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]], _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self._iterator^)

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] -> G.Collected[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _CarrierCompatible[G, R]:
        """Traverse effects and retain the original payloads on success."""
        return _traverse_as[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]], _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self._iterator^)

    def sequence_void[G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, G._LoopError[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]]] -> G._Looped[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]] where _Source[Self.I].Element == downcast[_Source[Self.I].Element, Movable & Deinitable] and _CarrierCompatible[G, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_void[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], G, _EntryError[X, G._LoopError[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]]]](_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]](), self._iterator^)

    def flat_traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]] where _Source[Self.I].Element == F.Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]], F.Error] and G.Element[F.Out] == List[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the flattened source shape. The callback produces a target effect of the same source family.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_then[ListFamily, G, Self.I, F, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]]](function^, self._iterator^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]())

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == List[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]())

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == List[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, E, F, True, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]())

    def flat_sequence[G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]] where _Source[Self.I].Element == downcast[_Source[Self.I].Element, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]], Never] and G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out] == List[_ListElement[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]] and _CarrierCompatible[G, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing the source shape after sequencing effects and flattening one source-family layer.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_then[ListFamily, G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]]](_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]](), self._iterator^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]())

    def traverse_filter[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]] where _Source[Self.I].Element == F.Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]], F.Error] and G.Element[F.Out] == Optional[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing present Optional results in source shape; absence discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_then[ListFamily, G, Self.I, F, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]]](function^, self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]())

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]())

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, E, F, True, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]())

    def filter_effect[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]] where _Source[Self.I].Element == downcast[C.Payload, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]], C.Failure] and G.Element[C.Result] == Bool and G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out]]] and _CarrierCompatible[G, C.Result]:
        """Retain elements accepted by an effectful borrowing Bool predicate.

        Parameters:
            C: The borrowing library callback type.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing original elements whose effectful Bool predicate succeeds with True; False discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_then[ListFamily, G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True](function^), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]())

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]], Never] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out]]] and _CarrierCompatible[G, R]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return _traverse_then[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]())

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]], E] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out]]] and _CarrierCompatible[G, R]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return _traverse_then[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]())

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Unary[A, R], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] -> ListFamily.Traversed[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] where Self.I.Element == A and _CollectCompatible[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.
            S: The error Semigroup; defaults to concatenation of list-valued stored errors.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            A Result containing the transformed source shape (List for Iter), or stored errors accumulated in source order. Every finite input is visited unless a native error is raised.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return ListFamily.traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, E, F, True, o]] -> ListFamily.Traversed[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, E, F, True, o]] where Self.I.Element == A and _CollectCompatible[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, E, F, True, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability."""
        return ListFamily.traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def par_traverse[F: UnaryContract & Movable & Deinitable, //, S: Semigroup = _ListErrors[F.Out]](deinit self, var function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, F] -> ListFamily.Traversed[ValidationFamily[S], Self.I, F] where Self.I.Element == F.Arg and _CollectCompatible[ValidationFamily[S], Self.I, F] and _CarrierCompatible[ValidationFamily[S], F.Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        return ListFamily.traverse[ValidationFamily[S]](function^, self._iterator^)

    def par_traverse[F: _UnaryViewable, o: ImmOrigin, //, S: Semigroup = _ListErrors[F._View[o].Out]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, F._View[o]] -> ListFamily.Traversed[ValidationFamily[S], Self.I, F._View[o]] where Self.I.Element == F._View[o].Arg and _CollectCompatible[ValidationFamily[S], Self.I, F._View[o]] and _CarrierCompatible[ValidationFamily[S], F._View[o].Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        return ListFamily.traverse[ValidationFamily[S]](function._unary_view(), self._iterator^)

    def par_sequence[S: Semigroup = _ListErrors[downcast[Self.I.Element, Movable & Deinitable]]](deinit self) raises S.Error -> ListFamily.Traversed[ValidationFamily[S], Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and _CollectCompatible[ValidationFamily[S], Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]] and _CarrierCompatible[ValidationFamily[S], downcast[Self.I.Element, Movable & Deinitable]]:
        """Derive par_sequence through traverse, preserving the family's semantics.

        Parameters:
            S: The error Semigroup; defaults to concatenation of list-valued stored errors.

        Returns:
            A Result containing unwrapped payloads in source shape (List for Iter), or stored errors accumulated in source order. An empty source succeeds; a source Result error stays inside the target Result.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_as[ListFamily, ValidationFamily[S], Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]], S.Error](_Same[downcast[Self.I.Element, Movable & Deinitable]](), self._iterator^)
    # --- end traversal conveniences ---

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 G: Applicative, F: _Unary[A, R]](deinit self, ref[o] function: F
    ) raises G.CollectError[Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] -> G.Collected[Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] where Self.I.Element == A:
        """Consume into an effect containing a List, stopping according to G.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            G: The target Applicative family; it determines effect sequencing and failure.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The target effect containing transformed payloads; Iter and direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return G.collect(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
                 G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F
    ) raises G.CollectError[Self.I, _NativeUnaryRef[A, R, E, F, True, o]] -> G.Collected[Self.I, _NativeUnaryRef[A, R, E, F, True, o]] where Self.I.Element == A:
        """Consume with a raising native callback and the exact target effect."""
        return G.collect(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def traverse[F: _UnaryViewable, o: ImmOrigin, //, G: Applicative](deinit self, ref[o] function: F
    ) raises G.CollectError[Self.I, F._View[o]] -> G.Collected[Self.I, F._View[o]] where Self.I.Element == F._View[o].Arg:
        """Traverse with a shared callable view, retaining its native origin."""
        return self^.traverse[G](function._unary_view())

    def traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative](deinit self, var function: F
    ) raises G.CollectError[Self.I, F] -> G.Collected[Self.I, F] where Self.I.Element == F.Arg:
        """Consume with an owned library callback and the target effect."""
        return G.collect(function^, self._iterator^)

    def sequence[G: Applicative](deinit self
    ) raises G.CollectError[Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]] -> G.Collected[Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]]:
        """Consume effects into one effect containing a List, stopping according to G.

        Parameters:
            G: The target Applicative family; it determines effect sequencing and failure.

        Returns:
            The target effect containing unwrapped payloads; Iter and direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return G.collect(_Same[downcast[Self.I.Element, Movable & Deinitable]](), self._iterator^)

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

    # --- effect syntax (generated) ---
    # Generated by scripts/generate_effect_syntax.py; execution lives in algebra._effect_combinators.

    def fold_effect[F: BinaryContract & Movable & Deinitable, //, G: Monad, Z: AnyType = _InferError](deinit self, var function: F, var initial: F.First) raises _EntryError[Z, _EffectFold[G, Self.I, F, _AllLive[F.First]].Error] -> _EffectFold[G, Self.I, F, _AllLive[F.First]].Out where _Source[Self.I].Element == F.Second and G.Element[F.Out] == F.First and _ErrorCompatible[_EntryError[Z, _EffectFold[G, Self.I, F, _AllLive[F.First]].Error], _EffectFold[G, Self.I, F, _AllLive[F.First]].Error] and _CarrierCompatible[G, F.Out]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Monad family; it determines dependent sequencing and failure.
            Z: The exact construction error for generic fold forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.
            initial: The initial accumulator, consumed.

        Returns:
            The target effect containing the final accumulator; empty input lifts the initial value.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_effect[G, Self.I, F, _AllLive[F.First], _EntryError[Z, _EffectFold[G, Self.I, F, _AllLive[F.First]].Error]](function^, initial^, self._iterator^)

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Binary[A, B, R], Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A]].Error] -> _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A]].Out where _Source[Self.I].Element == B and G.Element[R] == A and _ErrorCompatible[_EntryError[Z, _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A]].Error], _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A]].Error] and _CarrierCompatible[G, R]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        return _fold_effect[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A], _EntryError[Z, _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A]].Error]](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), initial^, self._iterator^)

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X], Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A]].Error] -> _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A]].Out where _Source[Self.I].Element == B and G.Element[R] == A and _ErrorCompatible[_EntryError[Z, _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A]].Error], _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A]].Error] and _CarrierCompatible[G, R]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        return _fold_effect[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A], _EntryError[Z, _EffectFold[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A]].Error]](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), initial^, self._iterator^)

    def any_effect[C: BorrowCallable, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[False]].Error] -> _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[False]].Out where _Source[Self.I].Element == downcast[C.Payload, Movable & Deinitable] and G.Element[C.Result] == Bool and _ErrorCompatible[_EntryError[X, _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[False]].Error], _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[False]].Error] and _CarrierCompatible[G, C.Result]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result.

        Parameters:
            C: The borrowing library callback type.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Bool, stopping each branch at True; empty input lifts False.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_effect[G, Self.I, _PredicateStep[C], _BoolLive[False], _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[False]].Error]](_PredicateStep[C](function^), False, self._iterator^)

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False]].Error] -> _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False]].Out where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and G.Element[R] == Bool and _ErrorCompatible[_EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False]].Error], _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False]].Error] and _CarrierCompatible[G, R]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False], _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), False, self._iterator^)

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False]].Error] -> _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False]].Out where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and G.Element[R] == Bool and _ErrorCompatible[_EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False]].Error], _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False]].Error] and _CarrierCompatible[G, R]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False], _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), False, self._iterator^)

    def all_effect[C: BorrowCallable, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[True]].Error] -> _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[True]].Out where _Source[Self.I].Element == downcast[C.Payload, Movable & Deinitable] and G.Element[C.Result] == Bool and _ErrorCompatible[_EntryError[X, _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[True]].Error], _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[True]].Error] and _CarrierCompatible[G, C.Result]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result.

        Parameters:
            C: The borrowing library callback type.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Bool, stopping each branch at False; empty input lifts True.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_effect[G, Self.I, _PredicateStep[C], _BoolLive[True], _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[C], _BoolLive[True]].Error]](_PredicateStep[C](function^), True, self._iterator^)

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True]].Error] -> _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True]].Out where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and G.Element[R] == Bool and _ErrorCompatible[_EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True]].Error], _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True]].Error] and _CarrierCompatible[G, R]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True], _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), True, self._iterator^)

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True]].Error] -> _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True]].Out where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and G.Element[R] == Bool and _ErrorCompatible[_EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True]].Error], _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True]].Error] and _CarrierCompatible[G, R]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True], _EntryError[X, _EffectFold[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), True, self._iterator^)
    # --- end effect syntax ---

    # --- terminal syntax (generated) ---
    # Generated by scripts/generate_plain_overloads.py; execution lives in iteration.reductions.

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> R where Self.I.Element == A:
        """Return the first present transformed result, stopping without another pull.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The first present Optional result, or absence; no later element is pulled.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _find_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> R where Self.I.Element == A:
        """Return the first present transformed result, stopping without another pull."""
        return _find_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def find_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> F.Out where Self.I.Element == F.Arg:
        """Return the first present transformed result, stopping without another pull."""
        return _find_map(function^, self._iterator^)

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> M.Value where Self.I.Element == A:
        """Project and combine in order with a monoid; empty input returns its identity.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            M: The Monoid providing the result type, identity and ordered combination.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The projected values combined in order, or the monoid identity on empty input.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_map[M=M](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> M.Value where Self.I.Element == A:
        """Project and combine in order with a monoid; empty input returns its identity."""
        return _fold_map[M=M](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def fold_map[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> M.Value where Self.I.Element == F.Arg:
        """Project and combine in order with a monoid; empty input returns its identity."""
        return _fold_map[M=M](function^, self._iterator^)

    def combine_all[M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> M.Value where Self.I.Element == M.Value:
        """Combine in order with a monoid; empty input returns its identity.

        Parameters:
            M: The Monoid providing the result type, identity and ordered combination.

        Returns:
            The values combined in order, or the monoid identity on empty input.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_map[M=M](_Same[M.Value](), self._iterator^)

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            An Optional containing the element with the smallest key; ties retain the first element.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, Never, F, False, o], smallest=True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, E, F, True, o], smallest=True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def min_by[C: BorrowCallable, //](deinit self, var function: C) raises C.Failure -> Optional[downcast[C.Payload, Movable & Deinitable]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and conforms_to(C.Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[C.Payload, Movable & Deinitable], C=C, smallest=True](function^, self._iterator^)

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            An Optional containing the element with the largest key; ties retain the first element.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, Never, F, False, o], smallest=False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, E, F, True, o], smallest=False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def max_by[C: BorrowCallable, //](deinit self, var function: C) raises C.Failure -> Optional[downcast[C.Payload, Movable & Deinitable]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and conforms_to(C.Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[C.Payload, Movable & Deinitable], C=C, smallest=False](function^, self._iterator^)

    def sum(deinit self) raises Never -> Int where Self.I.Element == Int:
        """Add in order from zero, preserving the numeric type and SIMD lanes.

        Returns:
            The ordered sum from zero, preserving the numeric type and SIMD lanes.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_map[M=_IntSum, E=Never](_Same[Int](), self._iterator^)

    def sum[dtype: DType, size: SIMDLength, //](deinit self) raises Never -> SIMD[dtype, size] where Self.I.Element == SIMD[dtype, size]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        return _fold_map[M=_SIMDSum[dtype, size], E=Never](_Same[SIMD[dtype, size]](), self._iterator^)

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Int where Self.I.Element == A and R == Int:
        """Project and add in one pass from zero, without an intermediate collection.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The ordered sum of projections from zero, without a mapped intermediate collection.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_map[M=_IntSum, E=Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Int where Self.I.Element == A and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_IntSum, E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def sum_by[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Int where Self.I.Element == F.Arg and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_IntSum, E=F.Error](function^, self._iterator^)

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> SIMD[dtype, size] where Self.I.Element == A and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_SIMDSum[dtype, size], E=Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> SIMD[dtype, size] where Self.I.Element == A and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_SIMDSum[dtype, size], E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> SIMD[dtype, size] where Self.I.Element == F.Arg and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_SIMDSum[dtype, size], E=F.Error](function^, self._iterator^)

    # --- end terminal syntax ---

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
