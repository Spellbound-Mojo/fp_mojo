"""Consuming method chains over native iterators."""
from .alignment import AlignIterator, AlignWithIterator, PadZipIterator, align as _align, align_with as _align_with, pad_zip as _pad_zip
from fp.data.ior import Ior
from .scans import ScanMapIterator, scan_map as _scan_map, _map_accumulate_owned
from ._callbacks import _LazyScanStep
from std.builtin.variadics import TypeList
from std.iter import _Enumerate, _ZipIterator, _ChainedIterator, enumerate as _std_enumerate
from std.itertools import take as _std_take, drop as _std_drop, take_while as _std_take_while, drop_while as _std_drop_while
from std.itertools.itertools import _TakeIterator, _DropIterator, _TakeWhileIterator, _DropWhileIterator
from fp.iteration._native import _OwnedSource, _NativeSources, _NativeTail, _SameSource, _native_zip, _native_chain
from fp.iteration.indexed import ZipWithIterator, IndexedMapIterator, zip_with as _zip_with, map_with_index as _map_with_index
from fp.iteration.prefixes import TakeWhileIterator, DropWhileIterator, take_while as _take_while, drop_while as _drop_while
from fp.iteration._callbacks import _LazyPredicate, _IndexedBinary, _LazyUnary
from fp.iteration.branching import _BufferPolicy, PartitionBranches, PartitionMapBranches, UnzipBranches, partition as _partition, partition_map as _partition_map, unzip as _unzip
from fp.callables.invoke import RepeatableUnary, RepeatableBorrow
from fp.iteration.terminals import first as _first, last as _last, is_empty as _is_empty, count as _count, contains as _contains, to_non_empty_list as _to_non_empty_list, combine_all_optional as _combine_all_optional, _count_where, _for_each, _collect_fold
from fp.data.non_empty_list import NonEmptyList
from fp.algebra._contracts import AnyContract, AllContract, FindContract, FindMapContract, FoldMapContract, FoldContract
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
from fp.callables._views import _UnaryViewable, _BorrowViewable
from fp.algebra.instances import _InferredApplicative, _OptionalElement, _ViewTarget
from fp.callables.protocols import BinaryContract
from fp.callables._views import _BinaryViewable
from fp.callables._receiver import _SharedBinaryRef
from fp.callables.invoke import RepeatableBinary
from fp.callables.native import _Binary, _RaisingBinary, _NativeBinaryRef, NativeBinary, _NativeOwnedArg
from std.builtin.rebind import rebind_var

from fp.algebra.instances import _ListElement

from fp.algebra._traversal import _FlattenAfter, _CompactAfter, _traverse_then, _Discard, _TraverseTap, _traverse_void, _traverse_as, _EffectVoid
from fp.callables.protocols import BorrowCallContract

from fp.callables._identity import Identity as _Same
from fp.callables.native import NativeUnary, _Unary, _RaisingUnary, _NativeUnaryRef, _Borrowing, _RaisingBorrowing, _NativeBorrowRef
from fp.iteration.reductions import _fold_map, _find_map, _extremum, _IntSum, _SIMDSum, _CanonicalMonoid
from fp.algebra.protocols import Monoid
from fp._internal.errors import _CommonError, _ErrorCompatible
from fp.callables.protocols import UnaryContract
from std.builtin.rebind import downcast
from fp.callables._transforms import _Fill, _Replace, _TupleWith, _ObserveOnce, _ObserveNative
from fp.iteration.adapters import _Map, _FilterMap
from fp.iteration.derived import compact as _derived_compact
from fp.algebra.instances import ListFamily
from fp.algebra.collections import _SourceFamily, _UnrecognizedCarrier, _CanonicalEffectMonoid
from fp.callables.protocols import _ErrorProbe, _BorrowErrorProbe, _BinaryErrorProbe
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


from fp.algebra._accumulation import _FirstPresent
from fp.algebra._effect_combinators import _SearchStep, _fold_map_effect
from fp.algebra._admission import _MapCompatible


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
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.

        Returns:
            Iter[ZipWithIterator[A, B, R, Self.I, _Source[W], def(var A, var B) thin -> R]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_zip_with(self._iterator^, other^, function))

    def zip_with[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, W: Movable & Deinitable, //, F: def(var A, var B) -> R](deinit self, var other: W, var function: F) -> Iter[ZipWithIterator[A, B, R, Self.I, _Source[W], F]] where Self.I.Element == A and _Source[W].Element == B:
        """Lazily combine pairs using native left-to-right zip followed by map.
        """
        return Iter(_zip_with(self._iterator^, other^, function^))

    def zip_with[F: BinaryContract & Movable & Deinitable, W: Movable & Deinitable](deinit self, var other: W, var function: F) -> Iter[ZipWithIterator[F.First, F.Second, F.Out, Self.I, _Source[W], F]] where Self.I.Element == F.First and _Source[W].Element == F.Second and F.Error == Never and RepeatableBinary[F]:
        """Lazily combine pairs using native left-to-right zip followed by map.
        """
        return Iter(_zip_with(self._iterator^, other^, function^))

    def zip_with[F: _BinaryViewable, o: ImmOrigin, W: Movable & Deinitable](deinit self, var other: W, ref[o] function: F) -> Iter[ZipWithIterator[_SharedBinaryRef[F, o].First, _SharedBinaryRef[F, o].Second, _SharedBinaryRef[F, o].Out, Self.I, _Source[W], _SharedBinaryRef[F, o]]] where Self.I.Element == _SharedBinaryRef[F, o].First and _Source[W].Element == _SharedBinaryRef[F, o].Second and _SharedBinaryRef[F, o].Error == Never and RepeatableBinary[_SharedBinaryRef[F, o]]:
        """Lazily combine pairs using native left-to-right zip followed by map.
        """
        return Iter(_zip_with(self._iterator^, other^, _SharedBinaryRef[F, o](Pointer(to=function))))

    def map_with_index[T: Movable & Deinitable, R: Movable & Deinitable](deinit self, var function: def(var Int, var T) thin -> R, *, start: Int = 0) -> Iter[IndexedMapIterator[T, R, Self.I, def(var Int, var T) thin -> R]] where Self.I.Element == T:
        """Lazily map (index, owned element), using native enumerate then map.

        Construction is inert; each output moves its inputs into the non-raising callback.
        Mapping fuses exhaustion and retains owned captures, move-only results and native origins.

        Parameters:
            T: The source element type, including origins.
            R: The callback result type.

        Args:
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.
            start: The first native Int index; defaults to zero.

        Returns:
            Iter[IndexedMapIterator[T, R, Self.I, def(var Int, var T) thin -> R]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_map_with_index(self._iterator^, function, start=start))

    def map_with_index[T: Movable & Deinitable, R: Movable & Deinitable, //, F: _IndexedBinary[T, R]](deinit self, var function: F, *, start: Int = 0) -> Iter[IndexedMapIterator[T, R, Self.I, F]] where Self.I.Element == T:
        """Lazily map (index, owned element), using native enumerate then map.
        """
        return Iter(_map_with_index(self._iterator^, function^, start=start))

    def map_with_index[F: BinaryContract & Movable & Deinitable](deinit self, var function: F, *, start: Int = 0) -> Iter[IndexedMapIterator[F.Second, F.Out, Self.I, F]] where Self.I.Element == F.Second and F.Error == Never and RepeatableBinary[F] and F.First == Int:
        """Lazily map (index, owned element), using native enumerate then map.
        """
        return Iter(_map_with_index(self._iterator^, function^, start=start))

    def map_with_index[F: _BinaryViewable, o: ImmOrigin](deinit self, ref[o] function: F, *, start: Int = 0) -> Iter[IndexedMapIterator[_SharedBinaryRef[F, o].Second, _SharedBinaryRef[F, o].Out, Self.I, _SharedBinaryRef[F, o]]] where Self.I.Element == _SharedBinaryRef[F, o].Second and _SharedBinaryRef[F, o].Error == Never and RepeatableBinary[_SharedBinaryRef[F, o]] and _SharedBinaryRef[F, o].First == Int:
        """Lazily map (index, owned element), using native enumerate then map.
        """
        return Iter(_map_with_index(self._iterator^, _SharedBinaryRef[F, o](Pointer(to=function)), start=start))

    def take_while[T: Movable & Deinitable](deinit self, var predicate: def(T) thin -> Bool) -> Iter[TakeWhileIterator[T, Self.I, def(T) thin -> Bool]] where Self.I.Element == T:
        """Yield the initial matching prefix; consume and discard its first rejection.

        Construction pulls nothing. The stored predicate borrows each candidate and cannot raise.
        Exhaustion is fused; abandonment releases captures and the unconsumed source.
        Uses constant state and preserves move-only elements and embedded origins.

        Parameters:
            T: The source element type, including origins.

        Args:
            predicate: The predicate, borrowing each candidate; the selected overload borrows or owns the predicate.

        Returns:
            Iter[TakeWhileIterator[T, Self.I, def(T) thin -> Bool]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_take_while(self._iterator^, predicate))

    def take_while[T: Movable & Deinitable, //, F: _LazyPredicate[T]](deinit self, var predicate: F) -> Iter[TakeWhileIterator[T, Self.I, F]] where Self.I.Element == T:
        """Yield the initial matching prefix; consume and discard its first rejection.
        """
        return Iter(_take_while(self._iterator^, predicate^))

    def take_while[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C) -> Iter[TakeWhileIterator[downcast[C.Payload, Movable & Deinitable], Self.I, C]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool and C.Failure == Never and RepeatableBorrow[C]:
        """Yield the initial matching prefix; consume and discard its first rejection.
        """
        return Iter(_take_while(self._iterator^, predicate^))

    def take_while[C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] predicate: C) -> Iter[TakeWhileIterator[downcast[C._BorrowView[o].Payload, Movable & Deinitable], Self.I, C._BorrowView[o]]] where Self.I.Element == downcast[C._BorrowView[o].Payload, Movable & Deinitable] and C._BorrowView[o].Result == Bool and C._BorrowView[o].Failure == Never:
        """Yield the initial matching prefix; consume and discard its first rejection.
        """
        return Iter(_take_while(self._iterator^, predicate._borrow_view()))

    def drop_while[T: Movable & Deinitable](deinit self, var predicate: def(T) thin -> Bool) -> Iter[DropWhileIterator[T, Self.I, def(T) thin -> Bool]] where Self.I.Element == T:
        """Discard the matching prefix; yield the first rejection and stop testing.

        Construction pulls nothing. The stored predicate borrows each candidate and cannot raise.
        Exhaustion is fused; abandonment releases captures and the unconsumed source.
        Uses constant state and preserves move-only elements and embedded origins.

        Parameters:
            T: The source element type, including origins.

        Args:
            predicate: The predicate, borrowing each candidate; the selected overload borrows or owns the predicate.

        Returns:
            Iter[DropWhileIterator[T, Self.I, def(T) thin -> Bool]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_drop_while(self._iterator^, predicate))

    def drop_while[T: Movable & Deinitable, //, F: _LazyPredicate[T]](deinit self, var predicate: F) -> Iter[DropWhileIterator[T, Self.I, F]] where Self.I.Element == T:
        """Discard the matching prefix; yield the first rejection and stop testing.
        """
        return Iter(_drop_while(self._iterator^, predicate^))

    def drop_while[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C) -> Iter[DropWhileIterator[downcast[C.Payload, Movable & Deinitable], Self.I, C]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool and C.Failure == Never and RepeatableBorrow[C]:
        """Discard the matching prefix; yield the first rejection and stop testing.
        """
        return Iter(_drop_while(self._iterator^, predicate^))

    def drop_while[C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] predicate: C) -> Iter[DropWhileIterator[downcast[C._BorrowView[o].Payload, Movable & Deinitable], Self.I, C._BorrowView[o]]] where Self.I.Element == downcast[C._BorrowView[o].Payload, Movable & Deinitable] and C._BorrowView[o].Result == Bool and C._BorrowView[o].Failure == Never:
        """Discard the matching prefix; yield the first rejection and stop testing.
        """
        return Iter(_drop_while(self._iterator^, predicate._borrow_view()))

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

    def count_where[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: def(P) -> R](deinit self, ref[o] predicate: F) raises Never -> Int where Self.I.Element == downcast[P, Movable & Deinitable] and R == Bool:
        """Count accepted candidates, borrowing each once; empty input returns zero.

        This is a consuming terminal. Native callbacks are borrowed in place;
        shared library views borrow their receiver; other library callbacks are
        consumed. Failure stops before the next pull and
        keeps its exact native type, including callback StopIteration. Move-only
        inputs and results retain their origins; no intermediate collection is built.

        Parameters:
            P: The admitted type parameter.
            R: The callback result type.
            o: The origin of the borrowed callback or comparison value.
            F: The concrete callback type, preserving captures and receiver semantics.

        Args:
            predicate: The predicate, borrowing each candidate; the selected overload borrows or owns the predicate.

        Returns:
            Int with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _count_where(_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=predicate)), self._iterator^)

    def count_where[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: def(P) raises E -> R](deinit self, ref[o] predicate: F) raises E -> Int where Self.I.Element == downcast[P, Movable & Deinitable] and R == Bool:
        """Count accepted candidates, borrowing each once; empty input returns zero.
        """
        return _count_where(_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=predicate)), self._iterator^)

    def count_where[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C) raises C.Failure -> Int where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool and RepeatableBorrow[C]:
        """Count accepted candidates, borrowing each once; empty input returns zero.
        """
        return _count_where(predicate^, self._iterator^)

    def count_where[C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] predicate: C) raises C._BorrowView[o].Failure -> Int where Self.I.Element == downcast[C._BorrowView[o].Payload, Movable & Deinitable] and C._BorrowView[o].Result == Bool:
        """Count accepted candidates, borrowing each once; empty input returns zero.
        """
        return _count_where(predicate._borrow_view(), self._iterator^)

    def for_each[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: def(var A) -> R](deinit self, ref[o] function: F) raises Never -> NoneType where Self.I.Element == A and R == NoneType:
        """Move each element into a callback returning NoneType, then return None.

        This is a consuming terminal. Native callbacks are borrowed in place;
        shared library views borrow their receiver; other library callbacks are
        consumed. Failure stops before the next pull and
        keeps its exact native type, including callback StopIteration. Move-only
        inputs and results retain their origins; no intermediate collection is built.

        Parameters:
            A: The first callback argument type.
            R: The callback result type.
            o: The origin of the borrowed callback or comparison value.
            F: The concrete callback type, preserving captures and receiver semantics.

        Args:
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.

        Returns:
            NoneType with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _for_each(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def for_each[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: def(var A) raises E -> R](deinit self, ref[o] function: F) raises E -> NoneType where Self.I.Element == A and R == NoneType:
        """Move each element into a callback returning NoneType, then return None.
        """
        return _for_each(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def for_each[F: UnaryContract & Movable & Deinitable](deinit self, var function: F) raises F.Error -> NoneType where Self.I.Element == F.Arg and F.Out == NoneType:
        """Move each element into a callback returning NoneType, then return None.
        """
        return _for_each(function^, self._iterator^)

    def for_each[F: _UnaryViewable, o: ImmOrigin](deinit self, ref[o] function: F) raises F._View[o].Error -> NoneType where Self.I.Element == F._View[o].Arg and F._View[o].Out == NoneType:
        """Move each element into a callback returning NoneType, then return None.
        """
        return _for_each(function._unary_view(), self._iterator^)

    def collect_fold[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: def(var A) -> R](deinit self, ref[o] function: F) raises M.Error -> M.Value where Self.I.Element == A and R == Optional[M.Value]:
        """Map to Optional monoid values, skip absence and combine present values in order.

        This is a consuming terminal. Native callbacks are borrowed in place;
        shared library views borrow their receiver; other library callbacks are
        consumed. Failure stops before the next pull and
        keeps its exact native type, including callback StopIteration. Move-only
        inputs and results retain their origins; no intermediate collection is built.

        Parameters:
            A: The first callback argument type.
            R: The callback result type.
            o: The origin of the borrowed callback or comparison value.
            M: The explicit Monoid; identity and combination retain its error type.
            F: The concrete callback type, preserving captures and receiver semantics.

        Args:
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.

        Returns:
            M.Value with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _collect_fold[M=M, E=M.Error](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def collect_fold[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: def(var A) raises E -> R](deinit self, ref[o] function: F) raises E -> M.Value where Self.I.Element == A and R == Optional[M.Value] and _ErrorCompatible[E, M.Error]:
        """Map to Optional monoid values, skip absence and combine present values in order.
        """
        return _collect_fold[M=M, E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def collect_fold[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> M.Value where Self.I.Element == F.Arg and F.Out == Optional[M.Value]:
        """Map to Optional monoid values, skip absence and combine present values in order.
        """
        return _collect_fold[M=M, E=_CommonError[F.Error, M.Error]](function^, self._iterator^)

    def collect_fold[F: _UnaryViewable, o: ImmOrigin, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> M.Value where Self.I.Element == F._View[o].Arg and F._View[o].Out == Optional[M.Value]:
        """Map to Optional monoid values, skip absence and combine present values in order.
        """
        return _collect_fold[M=M, E=_CommonError[F._View[o].Error, M.Error]](function._unary_view(), self._iterator^)

    def partition[T: Movable & Deinitable, P: _BufferPolicy](deinit self, var predicate: def(T) thin -> Bool, *, var buffer: P) -> PartitionBranches[T, Self.I, def(T) thin -> Bool, P] where Self.I.Element == T:
        """Lazily split accepted and rejected elements into independent iterators.

        Construction pulls nothing and each source item is classified once. Branches are move-only.
        Unbounded queues retain every pending value; BoundedFail yields Result elements,
        discards all queued values on overflow and gives each live branch one terminal Err.
        Close a branch to release its queue without draining upstream. Access is sequential;
        reentrant or overlapping access aborts before a second mutable state borrow.

        Parameters:
            T: The source element type, including origins.
            P: The admitted type parameter.

        Args:
            predicate: The predicate, borrowing each candidate; the selected overload borrows or owns the predicate.
            buffer: The required buffering policy; there is no implicit default.

        Returns:
            PartitionBranches[T, Self.I, def(T) thin -> Bool, P] with the ownership, timing and empty-input behavior described above.
        """
        return _partition[T=T](self._iterator^, predicate, buffer=buffer^)

    def partition[T: Movable & Deinitable, P: _BufferPolicy, //, F: _LazyPredicate[T]](deinit self, var predicate: F, *, var buffer: P) -> PartitionBranches[T, Self.I, F, P] where Self.I.Element == T:
        """Lazily split accepted and rejected elements into independent iterators.
        """
        return _partition[T=T](self._iterator^, predicate^, buffer=buffer^)

    def partition[C: BorrowCallContract & Movable & Deinitable, P: _BufferPolicy](deinit self, var predicate: C, *, var buffer: P) -> PartitionBranches[downcast[C.Payload, Movable & Deinitable], Self.I, C, P] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and C.Result == Bool and C.Failure == Never and RepeatableBorrow[C]:
        """Lazily split accepted and rejected elements into independent iterators.
        """
        return _partition(self._iterator^, predicate^, buffer=buffer^)

    def partition[C: _BorrowViewable, o: ImmOrigin, P: _BufferPolicy](deinit self, ref[o] predicate: C, *, var buffer: P) -> PartitionBranches[downcast[C._BorrowView[o].Payload, Movable & Deinitable], Self.I, C._BorrowView[o], P] where Self.I.Element == downcast[C._BorrowView[o].Payload, Movable & Deinitable] and C._BorrowView[o].Result == Bool and C._BorrowView[o].Failure == Never:
        """Lazily split accepted and rejected elements into independent iterators.
        """
        return _partition(self._iterator^, predicate._borrow_view(), buffer=buffer^)

    def partition_map[T: Movable & Deinitable, U: Movable & Deinitable, P: _BufferPolicy](deinit self, var function: def(var T) thin -> U, *, var buffer: P) -> PartitionMapBranches[T, U, Self.I, def(var T) thin -> U, P] where Self.I.Element == T and conforms_to(U, _ResultType):
        """Lazily route Result payloads into independent Ok and Err iterators.

        Construction pulls nothing and each source item is classified once. Branches are move-only.
        Unbounded queues retain every pending value; BoundedFail yields Result elements,
        discards all queued values on overflow and gives each live branch one terminal Err.
        Close a branch to release its queue without draining upstream. Access is sequential;
        reentrant or overlapping access aborts before a second mutable state borrow.

        Parameters:
            T: The source element type, including origins.
            U: The callback result type, including origins.
            P: The admitted type parameter.

        Args:
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.
            buffer: The required buffering policy; there is no implicit default.

        Returns:
            PartitionMapBranches[T, U, Self.I, def(var T) thin -> U, P] with the ownership, timing and empty-input behavior described above.
        """
        return _partition_map[T=T, U=U](self._iterator^, function, buffer=buffer^)

    def partition_map[T: Movable & Deinitable, U: Movable & Deinitable, P: _BufferPolicy, //, F: _LazyUnary[T, U]](deinit self, var function: F, *, var buffer: P) -> PartitionMapBranches[T, U, Self.I, F, P] where Self.I.Element == T and conforms_to(U, _ResultType):
        """Lazily route Result payloads into independent Ok and Err iterators.
        """
        return _partition_map[T=T, U=U](self._iterator^, function^, buffer=buffer^)

    def partition_map[F: UnaryContract & Movable & Deinitable, P: _BufferPolicy](deinit self, var function: F, *, var buffer: P) -> PartitionMapBranches[F.Arg, F.Out, Self.I, F, P] where Self.I.Element == F.Arg and conforms_to(F.Out, _ResultType) and F.Error == Never and RepeatableUnary[F]:
        """Lazily route Result payloads into independent Ok and Err iterators.
        """
        return _partition_map(self._iterator^, function^, buffer=buffer^)

    def partition_map[F: _UnaryViewable, o: ImmOrigin, P: _BufferPolicy](deinit self, ref[o] function: F, *, var buffer: P) -> PartitionMapBranches[F._View[o].Arg, F._View[o].Out, Self.I, F._View[o], P] where Self.I.Element == F._View[o].Arg and conforms_to(F._View[o].Out, _ResultType) and F._View[o].Error == Never and RepeatableUnary[F._View[o]]:
        """Lazily route Result payloads into independent Ok and Err iterators.
        """
        return _partition_map(self._iterator^, function._unary_view(), buffer=buffer^)

    def unzip[A: Movable & Deinitable, B: Movable & Deinitable, P: _BufferPolicy](deinit self, *, var buffer: P) -> UnzipBranches[A, B, Self.I, P] where Self.I.Element == Tuple[A, B]:
        """Lazily split native tuple fields, checking both queues before publishing either field.

        Construction pulls nothing and each source item is classified once. Branches are move-only.
        Unbounded queues retain every pending value; BoundedFail yields Result elements,
        discards all queued values on overflow and gives each live branch one terminal Err.
        Close a branch to release its queue without draining upstream. Access is sequential;
        reentrant or overlapping access aborts before a second mutable state borrow.

        Parameters:
            A: The first callback argument type.
            B: The second callback argument type.
            P: The admitted type parameter.

        Args:
            buffer: The required buffering policy; there is no implicit default.

        Returns:
            UnzipBranches[A, B, Self.I, P] with the ownership, timing and empty-input behavior described above.
        """
        return _unzip[A, B](self._iterator^, buffer=buffer^)

    def align[A: Movable & Deinitable, B: Movable & Deinitable, W: Movable & Deinitable](deinit self, var other: W) -> Iter[AlignIterator[A, B, Self.I, _Source[W]]] where Self.I.Element == A and _Source[W].Element == B:
        """Align positions to Ior until both sources end, without truncating either side.

        Construction pulls nothing; each output pulls each live side once, left before right.
        Exhausted sides are never polled again. Left and Right denote source sides.
        State is constant-sized; move-only payloads, captures and origins are preserved.

        Parameters:
            A: The first callback argument type.
            B: The second callback argument type.
            W: The second consumed source type.

        Args:
            other: The second source, consumed at its current position.

        Returns:
            Iter[AlignIterator[A, B, Self.I, _Source[W]]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_align[A=A, B=B](self._iterator^, other^))

    def pad_zip[A: Movable & Deinitable, B: Movable & Deinitable, W: Movable & Deinitable](deinit self, var other: W) -> Iter[PadZipIterator[A, B, Self.I, _Source[W]]] where Self.I.Element == A and _Source[W].Element == B:
        """Align positions to pairs of Optional fields, never yielding two absent fields.

        Construction pulls nothing; each output pulls each live side once, left before right.
        Exhausted sides are never polled again. Left and Right denote source sides.
        State is constant-sized; move-only payloads, captures and origins are preserved.

        Parameters:
            A: The first callback argument type.
            B: The second callback argument type.
            W: The second consumed source type.

        Args:
            other: The second source, consumed at its current position.

        Returns:
            Iter[PadZipIterator[A, B, Self.I, _Source[W]]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_pad_zip[A=A, B=B](self._iterator^, other^))

    def align_with[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, U: Movable & Deinitable, W: Movable & Deinitable](deinit self, var other: W, var function: def(var T) thin -> U) -> Iter[AlignWithIterator[A, B, U, Self.I, _Source[W], def(var T) thin -> U]] where Self.I.Element == A and _Source[W].Element == B and T == Ior[A, B]:
        """Map each owned Ior from alignment through a non-raising callback.

        Construction pulls nothing; each output pulls each live side once, left before right.
        Exhausted sides are never polled again. Left and Right denote source sides.
        State is constant-sized; move-only payloads, captures and origins are preserved.

        Parameters:
            A: The first callback argument type.
            B: The second callback argument type.
            T: The source element type, including origins.
            U: The callback result type, including origins.
            W: The second consumed source type.

        Args:
            other: The second source, consumed at its current position.
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.

        Returns:
            Iter[AlignWithIterator[A, B, U, Self.I, _Source[W], def(var T) thin -> U]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_align_with[A=A, B=B, T=T, U=U](self._iterator^, other^, function))

    def align_with[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, U: Movable & Deinitable, W: Movable & Deinitable, //, F: _LazyUnary[T, U]](deinit self, var other: W, var function: F) -> Iter[AlignWithIterator[A, B, U, Self.I, _Source[W], F]] where Self.I.Element == A and _Source[W].Element == B and T == Ior[A, B]:
        """Map each owned Ior from alignment through a non-raising callback.
        """
        return Iter(_align_with[A=A, B=B, T=T, U=U](self._iterator^, other^, function^))

    def align_with[A: Movable & Deinitable, B: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, W: Movable & Deinitable](deinit self, var other: W, var function: F) -> Iter[AlignWithIterator[A, B, F.Out, Self.I, _Source[W], F]] where Self.I.Element == A and _Source[W].Element == B and F.Arg == Ior[A, B] and F.Error == Never and RepeatableUnary[F]:
        """Map each owned Ior from alignment through a non-raising callback.
        """
        return Iter(_align_with[A=A, B=B](self._iterator^, other^, function^))

    def align_with[A: Movable & Deinitable, B: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, W: Movable & Deinitable](deinit self, var other: W, ref[o] function: F) -> Iter[AlignWithIterator[A, B, F._View[o].Out, Self.I, _Source[W], F._View[o]]] where Self.I.Element == A and _Source[W].Element == B and F._View[o].Arg == Ior[A, B] and F._View[o].Error == Never and RepeatableUnary[F._View[o]]:
        """Map each owned Ior from alignment through a non-raising callback.
        """
        return Iter(_align_with[A=A, B=B](self._iterator^, other^, function._unary_view()))

    def scan_map[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, R: Movable & Deinitable](deinit self, var function: def(var A, var T) thin -> R, var initial: A) -> Iter[ScanMapIterator[A, T, Y, Self.I, def(var A, var T) thin -> R]] where Self.I.Element == T and R == Tuple[A, Y]:
        """Lazily consume (carry, input) into (new carry, output), yielding one output per input.

        Construction pulls nothing and there is no initial output. The carry need not be Copyable.
        Each non-raising step moves both arguments; output and carry may have different types.
        Exhaustion is fused. Abandonment releases carry, callback and source; final carry is not exposed.

        Parameters:
            A: The first callback argument type.
            T: The source element type, including origins.
            Y: The independent scan output type, including origins.
            R: The callback result type.

        Args:
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.
            initial: The initial carry, consumed.

        Returns:
            Iter[ScanMapIterator[A, T, Y, Self.I, def(var A, var T) thin -> R]] with the ownership, timing and empty-input behavior described above.
        """
        return Iter(_scan_map[A=A, T=T, Y=Y](self._iterator^, initial^, function))

    def scan_map[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, var T) -> R](deinit self, var function: F, var initial: A) -> Iter[ScanMapIterator[A, T, Y, Self.I, F]] where Self.I.Element == T and R == Tuple[A, Y]:
        """Lazily consume (carry, input) into (new carry, output), yielding one output per input.
        """
        return Iter(_scan_map[A=A, T=T, Y=Y](self._iterator^, initial^, function^))

    def scan_map[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](deinit self, var function: F, var initial: A) -> Iter[ScanMapIterator[A, T, Y, Self.I, F]] where Self.I.Element == T and F.First == A and F.Second == T and F.Out == Tuple[A, Y] and F.Error == Never and RepeatableBinary[F]:
        """Lazily consume (carry, input) into (new carry, output), yielding one output per input.
        """
        return Iter(_scan_map[A=A, T=T, Y=Y](self._iterator^, initial^, function^))

    def scan_map[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: _BinaryViewable, o: ImmOrigin](deinit self, ref[o] function: F, var initial: A) -> Iter[ScanMapIterator[A, T, Y, Self.I, _SharedBinaryRef[F, o]]] where Self.I.Element == T and _SharedBinaryRef[F, o].First == A and _SharedBinaryRef[F, o].Second == T and _SharedBinaryRef[F, o].Out == Tuple[A, Y] and _SharedBinaryRef[F, o].Error == Never and RepeatableBinary[_SharedBinaryRef[F, o]]:
        """Lazily consume (carry, input) into (new carry, output), yielding one output per input.
        """
        return Iter(_scan_map[A=A, T=T, Y=Y](self._iterator^, initial^, _SharedBinaryRef[F, o](Pointer(to=function))))

    def map_accumulate[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](deinit self, var function: F, var initial: A) raises F.Error -> Tuple[A, List[Y]] where Self.I.Element == T and F.First == A and F.Second == T and F.Out == Tuple[A, Y] and RepeatableBinary[F]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.

        The step consumes (carry, element) and returns (next carry, output).
        The finite source is pulled once per step, in order; empty input returns the initial carry.
        Neither the carry nor elements nor outputs need to be Copyable. Mutable library steps
        take priority over shared invocation; consuming-only steps are rejected.
        Failures stop immediately and retain their exact type, including StopIteration.
        Capture native closures with BinarySignature; named standard binary adapters can be reused.
        Aliased native pointers select Y explicitly, and E for typed errors.

        Parameters:
            A: The first callback argument type.
            T: The source element type, including origins.
            Y: The independent scan output type, including origins.
            F: The concrete callback type, preserving captures and receiver semantics.

        Args:
            function: The callback, borrowed or owned according to the selected overload; captures retain their native origins.
            initial: The initial carry, consumed.

        Returns:
            Tuple[A, List[Y]] with the ownership, timing and empty-input behavior described above.

        Raises:
            The exact admitted callback or combination error; Never when non-raising.
        """
        return _map_accumulate_owned[A, T, Y, F, Self.I](function^, initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: _BinaryViewable, o: ImmOrigin](deinit self, ref[o] function: F, var initial: A) raises F.Error -> Tuple[A, List[Y]] where Self.I.Element == T and F.First == A and F.Second == T and F.Out == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, T, Y, _SharedBinaryRef[F, o], Self.I](_SharedBinaryRef[F, o](Pointer(to=function)), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, q: ImmOrigin, Y: Movable & Deinitable](deinit self, ref[q] function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: RegisterPassable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where not conforms_to(P, RegisterPassable) and not conforms_to(Q, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: RegisterPassable & Deinitable, R: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where not conforms_to(P, RegisterPassable) and not conforms_to(R, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where not conforms_to(P, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where not conforms_to(Q, RegisterPassable) and not conforms_to(R, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: Movable & Deinitable, R: RegisterPassable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where not conforms_to(Q, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: RegisterPassable & Deinitable, R: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where not conforms_to(R, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) thin -> R, var initial: A) raises Never -> Tuple[A, List[Y]] where P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, Never, type_of(function), False], Self.I](NativeBinary[P, Q, R, Never, type_of(function), False](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, Y: Movable & Deinitable](deinit self, ref[q] function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where not conforms_to(P, RegisterPassable) and not conforms_to(Q, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where not conforms_to(P, RegisterPassable) and not conforms_to(R, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: Movable & Deinitable, Q: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where not conforms_to(P, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where not conforms_to(Q, RegisterPassable) and not conforms_to(R, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where not conforms_to(Q, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where not conforms_to(R, RegisterPassable) and P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, P: RegisterPassable & Deinitable, Q: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, Y: Movable & Deinitable](deinit self, function: def(var P, var Q) raises E thin -> R, var initial: A) raises E -> Tuple[A, List[Y]] where P == A and Self.I.Element == Q and R == Tuple[A, Y]:
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, Q, Y, NativeBinary[P, Q, R, E, type_of(function), True], Self.I](NativeBinary[P, Q, R, E, type_of(function), True](function), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: Copyable & Deinitable, R: Movable & Deinitable = Tuple[A, Y]](deinit self, function: F, var initial: A) raises Never -> Tuple[A, List[Y]] where Self.I.Element == T and R == Tuple[A, Y] and not conforms_to(Tuple[A, Y], RegisterPassable) and F == (def(var _NativeOwnedArg[A], var _NativeOwnedArg[T]) thin -> R):
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, T, Y, NativeBinary[A, T, R, Never, F, False], Self.I](NativeBinary[A, T, R, Never, F, False](function.copy()), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: Copyable & Deinitable, R: RegisterPassable & Deinitable = downcast[Tuple[A, Y], RegisterPassable & Deinitable]](deinit self, function: F, var initial: A) raises Never -> Tuple[A, List[Y]] where Self.I.Element == T and R == Tuple[A, Y] and conforms_to(Tuple[A, Y], RegisterPassable) and F == (def(var _NativeOwnedArg[A], var _NativeOwnedArg[T]) thin -> R):
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, T, Y, NativeBinary[A, T, R, Never, F, False], Self.I](NativeBinary[A, T, R, Never, F, False](function.copy()), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: Copyable & Deinitable, R: Movable & Deinitable = Tuple[A, Y], E: Movable & Deinitable = Never](deinit self, function: F, var initial: A) raises E -> Tuple[A, List[Y]] where Self.I.Element == T and R == Tuple[A, Y] and not conforms_to(Tuple[A, Y], RegisterPassable) and F == (def(var _NativeOwnedArg[A], var _NativeOwnedArg[T]) raises E thin -> R):
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, T, Y, NativeBinary[A, T, R, E, F, True], Self.I](NativeBinary[A, T, R, E, F, True](function.copy()), initial^, self._iterator^)

    def map_accumulate[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: Copyable & Deinitable, R: RegisterPassable & Deinitable = downcast[Tuple[A, Y], RegisterPassable & Deinitable], E: Movable & Deinitable = Never](deinit self, function: F, var initial: A) raises E -> Tuple[A, List[Y]] where Self.I.Element == T and R == Tuple[A, Y] and conforms_to(Tuple[A, Y], RegisterPassable) and F == (def(var _NativeOwnedArg[A], var _NativeOwnedArg[T]) raises E thin -> R):
        """Thread a carry through the remaining source, returning the final carry and collected outputs.
        """
        return _map_accumulate_owned[A, T, Y, NativeBinary[A, T, R, E, F, True], Self.I](NativeBinary[A, T, R, E, F, True](function.copy()), initial^, self._iterator^)

    def fold_left[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](deinit self, var step: F, var initial: A) raises F.Error -> A where F.First == A and F.Second == Self.I.Element and F.Out == A and RepeatableBinary[F]:
        """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
        """
        return _fold_left[A=A, F=F](self._iterator^, initial^, step^)

    def reduce[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](deinit self, var step: F, *, var initial: A) raises F.Error -> A where F.First == A and F.Second == Self.I.Element and F.Out == A and RepeatableBinary[F]:
        """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
        """
        return _reduce[A=A, F=F](self._iterator^, step^, initial=initial^)

    def reduce_optional[F: BinaryContract & Movable & Deinitable](deinit self, var step: F) raises F.Error -> Optional[F.Out] where F.First == F.Out and F.Second == F.Out and Self.I.Element == F.Out and RepeatableBinary[F]:
        """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
        """
        return _reduce_optional[F=F](self._iterator^, step^)

    def reduce[F: BinaryContract & Movable & Deinitable](deinit self, var step: F) raises _ReductionFailure[F.Error] -> F.Out where F.First == F.Out and F.Second == F.Out and Self.I.Element == F.Out and RepeatableBinary[F]:
        """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
        """
        return _reduce[F=F](self._iterator^, step^)

    def fold_until[B: Movable & Deinitable, A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](deinit self, var step: F, var initial: A) raises F.Error -> ControlFlow[B, A] where F.First == A and F.Second == Self.I.Element and F.Out == ControlFlow[B, A] and RepeatableBinary[F]:
        """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
        """
        return _fold_until[B=B, A=A, F=F](self._iterator^, initial^, step^)

    def find[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C) raises C.Failure -> Optional[Self.I.Element] where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool and RepeatableBorrow[C]:
        """Search with an owned repeatable borrowing predicate, preferring its mutable receiver.
        """
        return _find[C=C](self._iterator^, predicate^)

    def any[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C) raises C.Failure -> Bool where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool and RepeatableBorrow[C]:
        """Search with an owned repeatable borrowing predicate, preferring its mutable receiver.
        """
        return _any[C=C](self._iterator^, predicate^)

    def all[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C) raises C.Failure -> Bool where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool and RepeatableBorrow[C]:
        """Search with an owned repeatable borrowing predicate, preferring its mutable receiver.
        """
        return _all[C=C](self._iterator^, predicate^)
    # --- end iterator expansion syntax ---

    # Native thin functions and closures keep their own admission signatures,
    # as in the free factories. Do not erase F or promote it to a library
    # callable: its exact type retains captures and embedded origins.
    def map[T: Movable & Deinitable, U: Movable & Deinitable](
        deinit self, function: def(var T) thin -> U
    ) -> Iter[MapIterator[T, U, Self.I]] where Self.I.Element == T:
        """Lazily transform each element and continue the chain.

        Each element is moved into the stored callback. Construction pulls nothing.
        Plain functions, capturing closures and non-raising repeatable library unary values
        use the same admission and execution as the free `map`.

        Parameters:
            T: The source element type.
            U: The result element type.

        Args:
            function: The non-raising callback, stored; move owned captures in with `^`.

        Returns:
            An `Iter` over the transformed elements.
        """
        return Iter(_map(self._iterator^, function))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //,
            F: def(var T) -> U](
        deinit self, var function: F
    ) -> Iter[MapIterator[T, U, Self.I, F]] where Self.I.Element == T:
        """Lazily transform each element with a stored closure."""
        return Iter(_map(self._iterator^, function^))

    def map[F: _UnaryViewable, o: ImmOrigin](deinit self, ref[o] function: F
    ) -> Iter[MapIterator[F._View[o].Arg, F._View[o].Out, Self.I, F._View[o]]] where Self.I.Element == F._View[o].Arg and F._View[o].Error == Never:
        """Retain a shared callable view in the lazy pipeline."""
        return Iter(_map(self._iterator^, function._unary_view()))

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) -> Iter[MapIterator[F.Arg, F.Out, Self.I, F]] where Self.I.Element == F.Arg and F.Error == Never and RepeatableUnary[F]:
        """Lazily transform each element with a repeatable library unary value."""
        return Iter(_map(self._iterator^, function^))


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

    def pair_with[P: AnyType, R: Movable & Deinitable, //, F: def(P) -> R](deinit self, var function: F
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
        return Iter(_derived_pair_with[P=P](self._iterator^, function^))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C
    ) -> Iter[_Map[T, Tuple[T, C.Result], Self.I, _ObserveOnce[T, C, True]]] where Self.I.Element == T and C.Payload == T and C.Failure == Never and RepeatableBorrow[C]:
        """Borrow each element and pair it with its projection. Evaluation is lazy."""
        return Iter(_derived_pair_with[T=T](self._iterator^, function^))

    def tap_each[P: AnyType, R: Movable & Deinitable, //, F: def(P) -> R](deinit self, var function: F
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
        return Iter(_derived_tap_each[P=P](self._iterator^, function^))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C
    ) -> Iter[_Map[T, T, Self.I, _ObserveOnce[T, C, False]]] where Self.I.Element == T and C.Payload == T and C.Failure == Never and RepeatableBorrow[C]:
        """Borrow each element and inspect it without changing it. Evaluation is lazy."""
        return Iter(_derived_tap_each[T=T](self._iterator^, function^))

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
        return Iter(_filter(self._iterator^, predicate))

    def filter[T: Movable & Deinitable, //, F: def(T) -> Bool](
        deinit self, var predicate: F
    ) -> Iter[FilterIterator[T, Self.I, F]] where Self.I.Element == T:
        """Lazily retain elements with a stored closure predicate."""
        return Iter(_filter(self._iterator^, predicate^))

    def filter[C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] predicate: C
    ) -> Iter[FilterIterator[Self.I.Element, Self.I, C._BorrowView[o]]] where conforms_to(Self.I.Element, Movable & Deinitable) and C._BorrowView[o].Payload == Self.I.Element and C._BorrowView[o].Result == Bool and C._BorrowView[o].Failure == Never:
        """Lazily filter with a retained shared predicate."""
        return Iter(_filter(self._iterator^, predicate._borrow_view()))

    def filter[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C
    ) -> Iter[FilterIterator[Self.I.Element, Self.I, C]] where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool and C.Failure == Never and RepeatableBorrow[C]:
        """Lazily retain elements with a library borrowing predicate."""
        return Iter(_filter(self._iterator^, predicate^))

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
        return Iter(_filter_not(self._iterator^, predicate))

    def filter_not[T: Movable & Deinitable, //, F: def(T) -> Bool](
        deinit self, var predicate: F
    ) -> Iter[FilterNotIterator[T, Self.I, F]] where Self.I.Element == T:
        """Lazily retain rejected elements with a stored native closure."""
        return Iter(_filter_not(self._iterator^, predicate^))

    def filter_not[C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] predicate: C
    ) -> Iter[FilterNotIterator[Self.I.Element, Self.I, C._BorrowView[o]]] where conforms_to(Self.I.Element, Movable & Deinitable) and C._BorrowView[o].Payload == Self.I.Element and C._BorrowView[o].Result == Bool and C._BorrowView[o].Failure == Never:
        """Lazily filter with a retained shared predicate."""
        return Iter(_filter_not(self._iterator^, predicate._borrow_view()))

    def filter_not[C: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C
    ) -> Iter[FilterNotIterator[Self.I.Element, Self.I, C]] where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool and C.Failure == Never and RepeatableBorrow[C]:
        """Lazily retain rejected elements with an owned library predicate."""
        return Iter(_filter_not(self._iterator^, predicate^))

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
        skipped; a present `Result.Err` remains an ordinary element.
        Library unary callbacks infer the Optional payload; an explicit `U=U` remains available.

        Parameters:
            T: The source element type.
            U: The element inside the returned `Optional`.

        Args:
            function: The non-raising callback returning `Optional[U]`, stored.

        Returns:
            An `Iter` over present results.
        """
        return Iter(_filter_map(self._iterator^, function))

    def filter_map[T: Movable & Deinitable, U: Movable & Deinitable, //,
                   F: def(var T) -> Optional[U]](
        deinit self, var function: F
    ) -> Iter[FilterMapIterator[T, U, Self.I, F]] where Self.I.Element == T:
        """Lazily transform and filter elements with a stored closure."""
        return Iter(_filter_map(self._iterator^, function^))

    def filter_map[U: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) -> Iter[FilterMapIterator[F.Arg, U, Self.I, F]] where Self.I.Element == F.Arg and F.Out == Optional[U] and F.Error == Never and RepeatableUnary[F]:
        """Lazily filter a repeatable library unary callback with an explicit Optional payload binding."""
        return Iter(_filter_map[U=U](self._iterator^, function^))

    def filter_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F
    ) -> Iter[FilterMapIterator[F.Arg, _OptionalElement[F.Out], Self.I, F]] where Self.I.Element == F.Arg and F.Out == Optional[_OptionalElement[F.Out]] and F.Error == Never and RepeatableUnary[F]:
        """Infer the Optional payload and move the callback into the lazy iterator."""
        return Iter(_filter_map[U=_OptionalElement[F.Out]](self._iterator^, function^))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, //,
                   U: Movable & Deinitable = _OptionalElement[F._View[o].Out]](
        deinit self, ref[o] function: F
    ) -> Iter[FilterMapIterator[F._View[o].Arg, U, Self.I, F._View[o]]] where Self.I.Element == F._View[o].Arg and F._View[o].Out == Optional[U] and F._View[o].Error == Never:
        """Infer the Optional payload and retain a shared callback until consumption."""
        return Iter(_filter_map[U=U](self._iterator^, function._unary_view()))

    def flat_map[T: Movable & Deinitable, U: Movable & Deinitable](
        deinit self, function: def(var T) thin -> U
    ) -> Iter[FlatMapIterator[T, U, Self.I]] where Self.I.Element == T:
        """Lazily expand each element and exhaust its inner source in order.

        Moves each element into the callback and retains the returned native
        iterator or owned iterable until it is exhausted or abandoned. Empty inner
        sources are skipped. A borrowed inner source retains its external origin.
        Plain functions, closures and non-raising repeatable library unary values are supported.

        Parameters:
            T: The source element type.
            U: The inner iterator or owned iterable returned by the callback.

        Args:
            function: The non-raising callback, stored; move owned captures in with `^`.

        Returns:
            An `Iter` over the concatenated inner elements.
        """
        return Iter(_flat_map(self._iterator^, function))

    def flat_map[T: Movable & Deinitable, U: Movable & Deinitable, //,
                 F: def(var T) -> U](
        deinit self, var function: F
    ) -> Iter[FlatMapIterator[T, U, Self.I, F]] where Self.I.Element == T:
        """Lazily expand each element with a stored closure."""
        return Iter(_flat_map(self._iterator^, function^))

    def flat_map[F: _UnaryViewable, o: ImmOrigin](deinit self, ref[o] function: F
    ) -> Iter[FlatMapIterator[F._View[o].Arg, F._View[o].Out, Self.I, F._View[o]]] where Self.I.Element == F._View[o].Arg and F._View[o].Error == Never:
        """Retain a shared callable view in the lazy pipeline."""
        return Iter(_flat_map(self._iterator^, function._unary_view()))

    def flat_map[F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) -> Iter[FlatMapIterator[F.Arg, F.Out, Self.I, F]] where Self.I.Element == F.Arg and F.Error == Never and RepeatableUnary[F]:
        """Lazily expand elements with a repeatable library unary value."""
        return Iter(_flat_map(self._iterator^, function^))

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

    def flat_tap[P: AnyType, R: Movable & Deinitable, //, C: def(P) -> R](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False]].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and P == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
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

    def flat_pair_with[P: AnyType, R: Movable & Deinitable, //, C: def(P) -> R](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False], False, True].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[P, R, C, False], False, True]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and P == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
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

    def followed_by[R: Movable & Deinitable, //, C: def() -> R](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]].Out, Self.I, _BorrowedUnary[downcast[Self.I.Element, Movable & Deinitable], _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
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

    def before[R: Movable & Deinitable, //, C: def() -> R](deinit self, var function: C) raises Never -> Iter[FlatMapIterator[downcast[Self.I.Element, Movable & Deinitable], _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]].Out, Self.I, _EffectRetain[downcast[Self.I.Element, Movable & Deinitable], _IteratorMap, _NativeBorrowMut[downcast[Self.I.Element, Movable & Deinitable], R, C, True]]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and Never == Never:
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
        return Iter(_scan_left(self._iterator^, initial^, step))

    def scan_left[A: Copyable & Deinitable, T: Movable & Deinitable, //,
                  F: def(var A, var T) -> A](
        deinit self, var step: F, var initial: A
    ) -> Iter[ScanIterator[A, T, Self.I, F]] where Self.I.Element == T:
        """Lazily yield accumulator snapshots with a stored closure."""
        return Iter(_scan_left(self._iterator^, initial^, step^))

    def scan_left[A: Copyable & Deinitable, F: BinaryContract & Movable & Deinitable](
        deinit self, var step: F, var initial: A
    ) -> Iter[ScanIterator[A, F.Second, Self.I, F]] where F.First == A and F.Second == Self.I.Element and F.Out == A and F.Error == Never and RepeatableBinary[F]:
        """Lazily yield accumulator snapshots with a shared or mutable library binary step."""
        return Iter(_scan_left(self._iterator^, initial^, step^))

    def scan_left[A: Copyable & Deinitable, F: _BinaryViewable, o: ImmOrigin](
        deinit self, ref[o] step: F, var initial: A
    ) -> Iter[ScanIterator[A, F.Second, Self.I, _SharedBinaryRef[F, o]]] where F.First == A and F.Second == Self.I.Element and F.Out == A and F.Error == Never:
        """Retain a shared step while yielding the same native accumulator snapshots."""
        return Iter(_scan_left(self._iterator^, initial^, _SharedBinaryRef[F, o](Pointer(to=step))))

    # --- traversal conveniences (generated) ---
    # Generated by scripts/generate_traversal_syntax.py; execution stays in algebra._traversal and families.

    def traverse_void[F: UnaryContract & Movable & Deinitable, //, G: Applicative = _InferredApplicative[F.Out], X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, G._LoopError[Self.I, F, _Discard[G.Element[F.Out]]]] -> G._Looped[Self.I, F, _Discard[G.Element[F.Out]]] where _Source[Self.I].Element == F.Arg and _CarrierCompatible[G, F.Out] and G._LoopCompatible[Self.I, F, _Discard[G.Element[F.Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_void[Self.I, F, G, _EntryError[X, G._LoopError[Self.I, F, _Discard[G.Element[F.Out]]]]](function^, self._iterator^)

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], F: def(var A) -> R = def(var A) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> G._Looped[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]] where _Source[Self.I].Element == A and _CarrierCompatible[G, R] and G._LoopCompatible[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return _traverse_void[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Self.I, _ErrorProbe[A, R, E], _Discard[G.Element[_ErrorProbe[A, R, E].Out]]]] -> G._Looped[Self.I, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]] where _Source[Self.I].Element == A and _CarrierCompatible[G, R] and G._LoopCompatible[Self.I, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        comptime assert _EntryError[X, G._LoopError[Self.I, _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] == _EntryError[X, G._LoopError[Self.I, _ErrorProbe[A, R, E], _Discard[G.Element[_ErrorProbe[A, R, E].Out]]]]
        return _traverse_void[Self.I, _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[Self.I, _ErrorProbe[A, R, E], _Discard[G.Element[_ErrorProbe[A, R, E].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def traverse_void[F: _UnaryViewable, o: ImmOrigin, //, G: Applicative = _ViewTarget[F, o], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Self.I, F._View[o], _Discard[G.Element[F._View[o].Out]]]] -> G._Looped[Self.I, F._View[o], _Discard[G.Element[F._View[o].Out]]] where _Source[Self.I].Element == F._View[o].Arg and _CarrierCompatible[G, F._View[o].Out] and G._LoopCompatible[Self.I, F._View[o], _Discard[G.Element[F._View[o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return _traverse_void[Self.I, F._View[o], G, _EntryError[X, G._LoopError[Self.I, F._View[o], _Discard[G.Element[F._View[o].Out]]]]](function._unary_view(), self._iterator^)

    def traverse_tap[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative = _InferredApplicative[C.Result], X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] -> G.Collected[Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]] where _Source[Self.I].Element == downcast[C.Payload, Movable & Deinitable] and _CarrierCompatible[G, C.Result] and ListFamily.TargetCompatible[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]:
        """Traverse effects and retain the original payloads on success.

        Parameters:
            C: The borrowing library callback type.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the original payloads, gathered in a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_as[ListFamily, G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C], _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C](function^), self._iterator^)

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], F: def(P) -> R = def(P) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] -> G.Collected[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return _traverse_as[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]], _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self._iterator^)

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], E: Movable & Deinitable = Never, F: def(P) raises E -> R = def(P) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E]]]] -> G.Collected[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]:
        """Traverse effects and retain the original payloads on success."""
        comptime assert _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] == _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E]]]]
        return _traverse_as[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]], _EntryError[X, G.CollectError[Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self._iterator^)

    def sequence_void[G: Applicative = _InferredApplicative[downcast[_Source[Self.I].Element, Movable & Deinitable]], X: AnyType = _InferError](deinit self) raises _EntryError[X, G._LoopError[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]]] -> G._Looped[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]] where _Source[Self.I].Element == downcast[_Source[Self.I].Element, Movable & Deinitable] and _CarrierCompatible[G, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out] and G._LoopCompatible[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_void[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], G, _EntryError[X, G._LoopError[Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _Discard[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]]]](_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]](), self._iterator^)

    def flat_traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative = _InferredApplicative[F.Out], X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]] where _Source[Self.I].Element == F.Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]], ListFamily.TraverseError[G, Self.I, F]] and G.Element[F.Out] == List[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out] and ListFamily.TargetCompatible[G, Self.I, F]:
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

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], F: def(var A) -> R = def(var A) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]] and G.Element[R] == List[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]())

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]], ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]] and G.Element[R] == List[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        comptime assert _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] == _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]]
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, E, F, True, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]())

    def flat_traverse[F: _UnaryViewable, o: ImmOrigin, //, G: Applicative = _ViewTarget[F, o], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F._View[o]], G.MapError[ListFamily.Traversed[G, Self.I, F._View[o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, F._View[o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]] where _Source[Self.I].Element == F._View[o].Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F._View[o]], G.MapError[ListFamily.Traversed[G, Self.I, F._View[o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]]]], ListFamily.TraverseError[G, Self.I, F._View[o]]] and G.Element[F._View[o].Out] == List[_ListElement[G.Element[F._View[o].Out]]] and _CarrierCompatible[G, F._View[o].Out] and ListFamily.TargetCompatible[G, Self.I, F._View[o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, F._View[o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F._View[o]], G.MapError[ListFamily.Traversed[G, Self.I, F._View[o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]]]]](function._unary_view(), self._iterator^, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]())

    def flat_sequence[G: Applicative = _InferredApplicative[downcast[_Source[Self.I].Element, Movable & Deinitable]], X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]] where _Source[Self.I].Element == downcast[_Source[Self.I].Element, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]], ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]] and G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out] == List[_ListElement[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]] and _CarrierCompatible[G, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out] and ListFamily.TargetCompatible[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]:
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

    def traverse_filter[F: UnaryContract & Movable & Deinitable, //, G: Applicative = _InferredApplicative[F.Out], X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]] where _Source[Self.I].Element == F.Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F], G.MapError[ListFamily.Traversed[G, Self.I, F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F]]]]]], ListFamily.TraverseError[G, Self.I, F]] and G.Element[F.Out] == Optional[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out] and ListFamily.TargetCompatible[G, Self.I, F]:
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

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], F: def(var A) -> R = def(var A) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]]]())

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]] where _Source[Self.I].Element == A and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]], ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        comptime assert _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] == _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]]
        return _traverse_then[ListFamily, G, Self.I, _NativeUnaryRef[A, R, E, F, True, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _ErrorProbe[A, R, E]], G.MapError[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _ErrorProbe[A, R, E]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]]]]())

    def traverse_filter[F: _UnaryViewable, o: ImmOrigin, //, G: Applicative = _ViewTarget[F, o], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F._View[o]], G.MapError[ListFamily.Traversed[G, Self.I, F._View[o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, F._View[o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]] where _Source[Self.I].Element == F._View[o].Arg and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F._View[o]], G.MapError[ListFamily.Traversed[G, Self.I, F._View[o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]]]], ListFamily.TraverseError[G, Self.I, F._View[o]]] and G.Element[F._View[o].Out] == Optional[_ListElement[G.Element[F._View[o].Out]]] and _CarrierCompatible[G, F._View[o].Out] and ListFamily.TargetCompatible[G, Self.I, F._View[o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return _traverse_then[ListFamily, G, Self.I, F._View[o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, F._View[o]], G.MapError[ListFamily.Traversed[G, Self.I, F._View[o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]]]]](function._unary_view(), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, F._View[o]]]]())

    def filter_effect[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative = _InferredApplicative[C.Result], X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]] where _Source[Self.I].Element == downcast[C.Payload, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]], ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]] and G.Element[C.Result] == Bool and G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out]]] and _CarrierCompatible[G, C.Result] and ListFamily.TargetCompatible[G, Self.I, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]:
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

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], F: def(P) -> R = def(P) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]], ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return _traverse_then[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]())

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative = _InferredApplicative[R], E: Movable & Deinitable = Never, F: def(P) raises E -> R = def(P) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]] where _Source[Self.I].Element == downcast[P, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]]]]]]], ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        comptime assert _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]] == _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]]]]]]]
        return _traverse_then[ListFamily, G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], G.MapError[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _BorrowErrorProbe[P, R, E], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]())

    def sequence_filter[G: Applicative = _InferredApplicative[downcast[_Source[Self.I].Element, Movable & Deinitable]], X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]] -> G.Mapped[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]] where _Source[Self.I].Element == downcast[_Source[Self.I].Element, Movable & Deinitable] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]], ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]] and G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out] == Optional[_ListElement[G.Element[_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out]]] and _CarrierCompatible[G, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]].Out] and ListFamily.TargetCompatible[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing present Optional payloads in source shape, using identity traverse_filter; effect failure remains distinct from discarded absence.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_then[ListFamily, G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], G.MapError[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]]]]](_Same[downcast[_Source[Self.I].Element, Movable & Deinitable]](), self._iterator^, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, Self.I, _Same[downcast[_Source[Self.I].Element, Movable & Deinitable]]]]]())

    def traverse[R: Movable & Deinitable, //, G: Applicative = _InferredApplicative[R]](deinit self, function: def(var _NativeOwnedArg[downcast[Self.I.Element, Movable & Deinitable]]) thin -> R) raises G.CollectError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]] -> G.Collected[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]] where not conforms_to(R, RegisterPassable) and G.CollectCompatible[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]]:
        """Copy a plain function into the existing traversal owner.

        Parameters:
            R: The native callback result type.
            G: The target Applicative family; it determines effect sequencing and failure.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The target effect containing transformed payloads; Iter and direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _traverse_as[ListFamily, G, Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], G.CollectError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]]](NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False](function), self._iterator^)

    def traverse[R: RegisterPassable & Deinitable, //, G: Applicative = _InferredApplicative[R]](deinit self, function: def(var _NativeOwnedArg[downcast[Self.I.Element, Movable & Deinitable]]) thin -> R) raises G.CollectError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]] -> G.Collected[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]] where G.CollectCompatible[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]]:
        """Copy a plain function into the existing traversal owner."""
        return _traverse_as[ListFamily, G, Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], G.CollectError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False]]](NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False](function), self._iterator^)

    def traverse[R: Movable & Deinitable, E: Movable & Deinitable, //, G: Applicative = _InferredApplicative[R]](deinit self, function: def(var _NativeOwnedArg[downcast[Self.I.Element, Movable & Deinitable]]) raises E thin -> R) raises G.CollectError[Self.I, _ErrorProbe[NoneType, R, E]] -> G.Collected[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True]] where G.CollectCompatible[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True]]:
        """Copy a plain function into the existing traversal owner."""
        comptime assert G.CollectError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True]] == G.CollectError[Self.I, _ErrorProbe[NoneType, R, E]]
        return _traverse_as[ListFamily, G, Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True], G.CollectError[Self.I, _ErrorProbe[NoneType, R, E]]](NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True](function), self._iterator^)

    def traverse_void[R: Movable & Deinitable, //, G: Applicative = _InferredApplicative[R], X: AnyType = _InferError](deinit self, function: def(var _NativeOwnedArg[downcast[Self.I.Element, Movable & Deinitable]]) thin -> R) raises _EntryError[X, G._LoopError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]]] -> G._Looped[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]] where not conforms_to(R, RegisterPassable) and _CarrierCompatible[G, R] and G._LoopCompatible[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]]:
        """Copy a plain function into the existing traversal owner."""
        return _traverse_void[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], G, _EntryError[X, G._LoopError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]]]](NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False](function), self._iterator^)

    def traverse_void[R: RegisterPassable & Deinitable, //, G: Applicative = _InferredApplicative[R], X: AnyType = _InferError](deinit self, function: def(var _NativeOwnedArg[downcast[Self.I.Element, Movable & Deinitable]]) thin -> R) raises _EntryError[X, G._LoopError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]]] -> G._Looped[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]] where _CarrierCompatible[G, R] and G._LoopCompatible[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]]:
        """Copy a plain function into the existing traversal owner."""
        return _traverse_void[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], G, _EntryError[X, G._LoopError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False].Out]]]]](NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, Never, type_of(function), False](function), self._iterator^)

    def traverse_void[R: Movable & Deinitable, E: Movable & Deinitable, //, G: Applicative = _InferredApplicative[R], X: AnyType = _InferError](deinit self, function: def(var _NativeOwnedArg[downcast[Self.I.Element, Movable & Deinitable]]) raises E thin -> R) raises _EntryError[X, G._LoopError[Self.I, _ErrorProbe[NoneType, R, E], _Discard[G.Element[_ErrorProbe[NoneType, R, E].Out]]]] -> G._Looped[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True].Out]]] where _CarrierCompatible[G, R] and G._LoopCompatible[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True].Out]]]:
        """Copy a plain function into the existing traversal owner."""
        comptime assert _EntryError[X, G._LoopError[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True], _Discard[G.Element[NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True].Out]]]] == _EntryError[X, G._LoopError[Self.I, _ErrorProbe[NoneType, R, E], _Discard[G.Element[_ErrorProbe[NoneType, R, E].Out]]]]
        return _traverse_void[Self.I, NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True], G, _EntryError[X, G._LoopError[Self.I, _ErrorProbe[NoneType, R, E], _Discard[G.Element[_ErrorProbe[NoneType, R, E].Out]]]]](NativeUnary[downcast[Self.I.Element, Movable & Deinitable], R, E, type_of(function), True](function), self._iterator^)

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: def(var A) -> R, //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] -> ListFamily.Traversed[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] where Self.I.Element == A and ListFamily.TargetCompatible[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] and _CarrierCompatible[ValidationFamily[S], R]:
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

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, E: Movable & Deinitable, F: def(var A) raises E -> R, //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, E, F, True, o]] -> ListFamily.Traversed[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, E, F, True, o]] where Self.I.Element == A and ListFamily.TargetCompatible[ValidationFamily[S], Self.I, _NativeUnaryRef[A, R, E, F, True, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability."""
        return ListFamily.traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def par_traverse[F: UnaryContract & Movable & Deinitable, //, S: Semigroup = _ListErrors[F.Out]](deinit self, var function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, F] -> ListFamily.Traversed[ValidationFamily[S], Self.I, F] where Self.I.Element == F.Arg and ListFamily.TargetCompatible[ValidationFamily[S], Self.I, F] and _CarrierCompatible[ValidationFamily[S], F.Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        return ListFamily.traverse[ValidationFamily[S]](function^, self._iterator^)

    def par_traverse[F: _UnaryViewable, o: ImmOrigin, //, S: Semigroup = _ListErrors[F._View[o].Out]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], Self.I, F._View[o]] -> ListFamily.Traversed[ValidationFamily[S], Self.I, F._View[o]] where Self.I.Element == F._View[o].Arg and ListFamily.TargetCompatible[ValidationFamily[S], Self.I, F._View[o]] and _CarrierCompatible[ValidationFamily[S], F._View[o].Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        return ListFamily.traverse[ValidationFamily[S]](function._unary_view(), self._iterator^)

    def par_sequence[S: Semigroup = _ListErrors[downcast[Self.I.Element, Movable & Deinitable]]](deinit self) raises S.Error -> ListFamily.Traversed[ValidationFamily[S], Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]] where Self.I.Element == downcast[Self.I.Element, Movable & Deinitable] and ListFamily.TargetCompatible[ValidationFamily[S], Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]] and _CarrierCompatible[ValidationFamily[S], downcast[Self.I.Element, Movable & Deinitable]]:
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
                 G: Applicative = _InferredApplicative[R], F: def(var A) -> R = def(var A) -> R](deinit self, ref[o] function: F
    ) raises G.CollectError[Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] -> G.Collected[Self.I, _NativeUnaryRef[A, R, Never, F, False, o]] where Self.I.Element == A and G.CollectCompatible[Self.I, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Consume into an effect containing a List, stopping according to G.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            G: The target Applicative family; it determines effect sequencing and failure. Defaults to the family of the callback's result.
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
                 G: Applicative = _InferredApplicative[R], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R](deinit self, ref[o] function: F
    ) raises G.CollectError[Self.I, _NativeUnaryRef[A, R, E, F, True, o]] -> G.Collected[Self.I, _NativeUnaryRef[A, R, E, F, True, o]] where Self.I.Element == A and G.CollectCompatible[Self.I, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Consume with a raising native callback and the exact target effect."""
        return G.collect(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def traverse[F: _UnaryViewable, o: ImmOrigin, //, G: Applicative = _ViewTarget[F, o]](deinit self, ref[o] function: F
    ) raises G.CollectError[Self.I, F._View[o]] -> G.Collected[Self.I, F._View[o]] where Self.I.Element == F._View[o].Arg and G.CollectCompatible[Self.I, F._View[o]]:
        """Traverse with a shared callable view, retaining its native origin."""
        return self^.traverse[G](function._unary_view())

    def traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative = _InferredApplicative[F.Out]](deinit self, var function: F
    ) raises G.CollectError[Self.I, F] -> G.Collected[Self.I, F] where Self.I.Element == F.Arg and G.CollectCompatible[Self.I, F]:
        """Consume with an owned library callback and the target effect."""
        return G.collect(function^, self._iterator^)

    def sequence[G: Applicative = _InferredApplicative[downcast[Self.I.Element, Movable & Deinitable]]](deinit self
    ) raises G.CollectError[Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]] -> G.Collected[Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]] where G.CollectCompatible[Self.I, _Same[downcast[Self.I.Element, Movable & Deinitable]]]:
        """Consume effects into one effect containing a List, stopping according to G.

        Parameters:
            G: The target Applicative family, inferred from the complete element type; select Validation or an external family explicitly.

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

    def fold_effect[F: BinaryContract & Movable & Deinitable, //, G: Monad = downcast[_SourceFamily[F.Out] if conforms_to(_SourceFamily[F.Out], Monad) else _UnrecognizedCarrier, Monad], Z: AnyType = _InferError](deinit self, var function: F, var initial: F.First) raises _EntryError[Z, FoldContract[G, Self.I, F].Error] -> FoldContract[G, Self.I, F].Out where FoldContract[G, Self.I, F].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, Self.I, F].Error], FoldContract[G, Self.I, F].Error]:
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
        return _fold_effect[G, Self.I, F, _AllLive[F.First], _EntryError[Z, FoldContract[G, Self.I, F].Error]](function^, initial^, self._iterator^)

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], F: def(var A, var B) -> R = def(var A, var B) -> R, Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error] -> FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o]].Out where FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error], FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        return _fold_effect[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A], _EntryError[Z, FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error]](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), initial^, self._iterator^)

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], X: Movable & Deinitable = Never, F: def(var A, var B) raises X -> R = def(var A, var B) raises X -> R, Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, FoldContract[G, Self.I, _BinaryErrorProbe[A, B, R, X]].Error] -> FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o]].Out where FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o]].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, Self.I, _BinaryErrorProbe[A, B, R, X]].Error], FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o]].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        comptime assert _EntryError[Z, FoldContract[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o]].Error] == _EntryError[Z, FoldContract[G, Self.I, _BinaryErrorProbe[A, B, R, X]].Error]
        return _fold_effect[G, Self.I, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A], _EntryError[Z, FoldContract[G, Self.I, _BinaryErrorProbe[A, B, R, X]].Error]](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), initial^, self._iterator^)

    def any_effect[C: BorrowCallable, //, G: Monad = downcast[_SourceFamily[C.Result] if conforms_to(_SourceFamily[C.Result], Monad) else _UnrecognizedCarrier, Monad], X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, AnyContract[G, Self.I, C].Error] -> AnyContract[G, Self.I, C].Out where AnyContract[G, Self.I, C].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, Self.I, C].Error], AnyContract[G, Self.I, C].Error]:
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
        return _fold_effect[G, Self.I, _PredicateStep[C], _BoolLive[False], _EntryError[X, AnyContract[G, Self.I, C].Error]](_PredicateStep[C](function^), False, self._iterator^)

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], F: def(P) -> R = def(P) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AnyContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> AnyContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Out where AnyContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error], AnyContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False], _EntryError[X, AnyContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), False, self._iterator^)

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], E: Movable & Deinitable = Never, F: def(P) raises E -> R = def(P) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AnyContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error] -> AnyContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Out where AnyContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error], AnyContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        comptime assert _EntryError[X, AnyContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Error] == _EntryError[X, AnyContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error]
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False], _EntryError[X, AnyContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), False, self._iterator^)

    def all_effect[C: BorrowCallable, //, G: Monad = downcast[_SourceFamily[C.Result] if conforms_to(_SourceFamily[C.Result], Monad) else _UnrecognizedCarrier, Monad], X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, AllContract[G, Self.I, C].Error] -> AllContract[G, Self.I, C].Out where AllContract[G, Self.I, C].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, Self.I, C].Error], AllContract[G, Self.I, C].Error]:
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
        return _fold_effect[G, Self.I, _PredicateStep[C], _BoolLive[True], _EntryError[X, AllContract[G, Self.I, C].Error]](_PredicateStep[C](function^), True, self._iterator^)

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], F: def(P) -> R = def(P) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AllContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> AllContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Out where AllContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error], AllContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True], _EntryError[X, AllContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), True, self._iterator^)

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], E: Movable & Deinitable = Never, F: def(P) raises E -> R = def(P) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AllContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error] -> AllContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Out where AllContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error], AllContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        comptime assert _EntryError[X, AllContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Error] == _EntryError[X, AllContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error]
        return _fold_effect[G, Self.I, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True], _EntryError[X, AllContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), True, self._iterator^)

    def find_effect[C: BorrowCallable, //, G: Monad = downcast[_SourceFamily[C.Result] if conforms_to(_SourceFamily[C.Result], Monad) else _UnrecognizedCarrier, Monad], X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, FindContract[G, Self.I, C].Error] -> FindContract[G, Self.I, C].Out where FindContract[G, Self.I, C].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, Self.I, C].Error], C.Failure] or _ErrorCompatible[_EntryError[X, FindContract[G, Self.I, C].Error], FindContract[G, Self.I, C].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch.

        Parameters:
            C: The borrowing library callback type.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Optional, stopping each live branch at its first accepted original element; empty input lifts None.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_effect[G, Self.I, _SearchStep[downcast[C.Payload, Movable & Deinitable], _EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True]], _FirstPresent[downcast[C.Payload, Movable & Deinitable]], _EntryError[X, FindContract[G, Self.I, C].Error]](_SearchStep[downcast[C.Payload, Movable & Deinitable], _EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True]](_EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True](function^)), Optional[downcast[C.Payload, Movable & Deinitable]](), self._iterator^)

    def find_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], F: def(P) -> R = def(P) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> FindContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Out where FindContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FindContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error], FindContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch."""
        return _fold_effect[G, Self.I, _SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _FirstPresent[downcast[P, Movable & Deinitable]], _EntryError[X, FindContract[G, Self.I, _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]](_EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)))), Optional[downcast[P, Movable & Deinitable]](), self._iterator^)

    def find_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], E: Movable & Deinitable = Never, F: def(P) raises E -> R = def(P) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error] -> FindContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Out where FindContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error], E] or _ErrorCompatible[_EntryError[X, FindContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error], FindContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch."""
        comptime assert _EntryError[X, FindContract[G, Self.I, _NativeBorrowRef[P, R, E, F, True, o]].Error] == _EntryError[X, FindContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error]
        return _fold_effect[G, Self.I, _SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _FirstPresent[downcast[P, Movable & Deinitable]], _EntryError[X, FindContract[G, Self.I, _BorrowErrorProbe[P, R, E]].Error]](_SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]](_EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)))), Optional[downcast[P, Movable & Deinitable]](), self._iterator^)

    def find_map_effect[F: UnaryContract & Movable & Deinitable, //, G: Monad = downcast[_SourceFamily[F.Out] if conforms_to(_SourceFamily[F.Out], Monad) else _UnrecognizedCarrier, Monad], X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, FindMapContract[G, Self.I, F].Error] -> FindMapContract[G, Self.I, F].Out where FindMapContract[G, Self.I, F].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, Self.I, F].Error], F.Error] or _ErrorCompatible[_EntryError[X, FindMapContract[G, Self.I, F].Error], FindMapContract[G, Self.I, F].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of the first present Optional in each live branch; empty input lifts None and target failure stays in the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_effect[G, Self.I, _SearchStep[_ListElement[G.Element[F.Out]], F], _FirstPresent[_ListElement[G.Element[F.Out]]], _EntryError[X, FindMapContract[G, Self.I, F].Error]](_SearchStep[_ListElement[G.Element[F.Out]], F](function^), Optional[_ListElement[G.Element[F.Out]]](), self._iterator^)

    def find_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], F: def(var A) -> R = def(var A) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindMapContract[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error] -> FindMapContract[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Out where FindMapContract[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FindMapContract[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error], FindMapContract[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch."""
        return _fold_effect[G, Self.I, _SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, Never, F, False, o]], _FirstPresent[_ListElement[G.Element[R]]], _EntryError[X, FindMapContract[G, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error]](_SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), Optional[_ListElement[G.Element[R]]](), self._iterator^)

    def find_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindMapContract[G, Self.I, _ErrorProbe[A, R, E]].Error] -> FindMapContract[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Out where FindMapContract[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, Self.I, _ErrorProbe[A, R, E]].Error], E] or _ErrorCompatible[_EntryError[X, FindMapContract[G, Self.I, _ErrorProbe[A, R, E]].Error], FindMapContract[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch."""
        comptime assert _EntryError[X, FindMapContract[G, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Error] == _EntryError[X, FindMapContract[G, Self.I, _ErrorProbe[A, R, E]].Error]
        return _fold_effect[G, Self.I, _SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, E, F, True, o]], _FirstPresent[_ListElement[G.Element[R]]], _EntryError[X, FindMapContract[G, Self.I, _ErrorProbe[A, R, E]].Error]](_SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), Optional[_ListElement[G.Element[R]]](), self._iterator^)

    def fold_map_effect[F: UnaryContract & Movable & Deinitable, //, M: Monoid = _CanonicalEffectMonoid[F.Out], G: Monad = downcast[_SourceFamily[F.Out] if conforms_to(_SourceFamily[F.Out], Monad) else _UnrecognizedCarrier, Monad], X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, FoldMapContract[G, M, Self.I, F].Error] -> FoldMapContract[G, M, Self.I, F].Out where FoldMapContract[G, M, Self.I, F].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, F].Error], F.Error] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, F].Error], FoldMapContract[G, M, Self.I, F].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, F].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            M: The Monoid providing the result type, identity and ordered combination.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of ordered monoid combination. Identity is constructed before source binding, including for deferred targets; callbacks and combinations follow the target timing.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_map_effect[G, M, Self.I, F, _EntryError[X, FoldMapContract[G, M, Self.I, F].Error]](function^, self._iterator^)

    def fold_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid = _CanonicalEffectMonoid[R], G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], F: def(var A) -> R = def(var A) -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error] -> FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Out where FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error], FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid."""
        return _fold_map_effect[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o], _EntryError[X, FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, Never, F, False, o]].Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def fold_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid = _CanonicalEffectMonoid[R], G: Monad = downcast[_SourceFamily[R] if conforms_to(_SourceFamily[R], Monad) else _UnrecognizedCarrier, Monad], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FoldMapContract[G, M, Self.I, _ErrorProbe[A, R, E]].Error] -> FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Out where FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, _ErrorProbe[A, R, E]].Error], E] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, _ErrorProbe[A, R, E]].Error], FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.I, _ErrorProbe[A, R, E]].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid."""
        comptime assert _EntryError[X, FoldMapContract[G, M, Self.I, _NativeUnaryRef[A, R, E, F, True, o]].Error] == _EntryError[X, FoldMapContract[G, M, Self.I, _ErrorProbe[A, R, E]].Error]
        return _fold_map_effect[G, M, Self.I, _NativeUnaryRef[A, R, E, F, True, o], _EntryError[X, FoldMapContract[G, M, Self.I, _ErrorProbe[A, R, E]].Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)
    # --- end effect syntax ---

    # --- terminal syntax (generated) ---
    # Generated by scripts/generate_plain_overloads.py; execution lives in iteration.reductions.

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: def(var A) -> R](deinit self, ref[o] function: F) raises Never -> R where Self.I.Element == A:
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

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: def(var A) raises E -> R](deinit self, ref[o] function: F) raises E -> R where Self.I.Element == A:
        """Return the first present transformed result, stopping without another pull."""
        return _find_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def find_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> F.Out where Self.I.Element == F.Arg:
        """Return the first present transformed result, stopping without another pull."""
        return _find_map(function^, self._iterator^)

    def find_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> F._View[o].Out where Self.I.Element == F._View[o].Arg:
        """Return the first present transformed result, stopping without another pull."""
        return _find_map(function._unary_view(), self._iterator^)

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid = _CanonicalMonoid[R], F: def(var A) -> R = def(var A) -> R](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> M.Value where Self.I.Element == A and R == M.Value:
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

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid = _CanonicalMonoid[R], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> M.Value where Self.I.Element == A and R == M.Value:
        """Project and combine in order with a monoid; empty input returns its identity."""
        return _fold_map[M=M](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def fold_map[F: UnaryContract & Movable & Deinitable, //, M: Monoid = _CanonicalMonoid[F.Out]](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> M.Value where Self.I.Element == F.Arg and F.Out == M.Value:
        """Project and combine in order with a monoid; empty input returns its identity."""
        return _fold_map[M=M](function^, self._iterator^)

    def fold_map[F: _UnaryViewable, o: ImmOrigin, //, M: Monoid = _CanonicalMonoid[F._View[o].Out]](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> M.Value where Self.I.Element == F._View[o].Arg and F._View[o].Out == M.Value:
        """Project and combine in order with a monoid; empty input returns its identity."""
        return _fold_map[M=M](function._unary_view(), self._iterator^)

    def combine_all[M: Monoid = _CanonicalMonoid[downcast[Self.I.Element, Movable & Deinitable]]](deinit self) raises _CommonError[Never, M.Error] -> M.Value where Self.I.Element == M.Value:
        """Combine in order with a monoid; empty input returns its identity.

        Parameters:
            M: The Monoid providing the result type, identity and ordered combination.

        Returns:
            The values combined in order, or the monoid identity on empty input.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return _fold_map[M=M](_Same[M.Value](), self._iterator^)

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: def(P) -> R](deinit self, ref[o] function: F) raises Never -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
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

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: def(P) raises E -> R](deinit self, ref[o] function: F) raises E -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, E, F, True, o], smallest=True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def min_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Optional[downcast[C.Payload, Movable & Deinitable]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[C.Payload, Movable & Deinitable], C=C, smallest=True](function^, self._iterator^)

    def min_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] where Self.I.Element == downcast[C._BorrowView[o].Payload, Movable & Deinitable] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[C._BorrowView[o].Payload, Movable & Deinitable], C=C._BorrowView[o], smallest=True](function._borrow_view(), self._iterator^)

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: def(P) -> R](deinit self, ref[o] function: F) raises Never -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
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

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: def(P) raises E -> R](deinit self, ref[o] function: F) raises E -> Optional[downcast[P, Movable & Deinitable]] where Self.I.Element == downcast[P, Movable & Deinitable] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[P, Movable & Deinitable], C=_NativeBorrowRef[P, R, E, F, True, o], smallest=False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def max_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Optional[downcast[C.Payload, Movable & Deinitable]] where Self.I.Element == downcast[C.Payload, Movable & Deinitable] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[C.Payload, Movable & Deinitable], C=C, smallest=False](function^, self._iterator^)

    def max_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] where Self.I.Element == downcast[C._BorrowView[o].Payload, Movable & Deinitable] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        return _extremum[T=downcast[C._BorrowView[o].Payload, Movable & Deinitable], C=C._BorrowView[o], smallest=False](function._borrow_view(), self._iterator^)

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

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: def(var A) -> R](deinit self, ref[o] function: F) raises Never -> Int where Self.I.Element == A and R == Int:
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

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: def(var A) raises E -> R](deinit self, ref[o] function: F) raises E -> Int where Self.I.Element == A and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_IntSum, E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def sum_by[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Int where Self.I.Element == F.Arg and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_IntSum, E=F.Error](function^, self._iterator^)

    def sum_by[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Int where Self.I.Element == F._View[o].Arg and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_IntSum, E=F._View[o].Error](function._unary_view(), self._iterator^)

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: def(var A) -> R](deinit self, ref[o] function: F) raises Never -> SIMD[dtype, size] where Self.I.Element == A and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_SIMDSum[dtype, size], E=Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self._iterator^)

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: def(var A) raises E -> R](deinit self, ref[o] function: F) raises E -> SIMD[dtype, size] where Self.I.Element == A and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_SIMDSum[dtype, size], E=E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self._iterator^)

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> SIMD[dtype, size] where Self.I.Element == F.Arg and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_SIMDSum[dtype, size], E=F.Error](function^, self._iterator^)

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> SIMD[dtype, size] where Self.I.Element == F._View[o].Arg and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        return _fold_map[M=_SIMDSum[dtype, size], E=F._View[o].Error](function._unary_view(), self._iterator^)

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
        return _fold_left(self._iterator^, initial^, step)

    # Pass E explicitly through every raising boundary. Reading F.E or inferring
    # it again loses the caller's error equality in precompiled generic clients.
    def fold_left[A: Movable & Deinitable, T: Movable & Deinitable, E: AnyType, //,
                  F: def(var A, var T) raises E -> A](
        deinit self, step: F, var initial: A
    ) raises E -> A where Self.I.Element == T:
        """Fold with a raising step, propagating its exact error type."""
        return _fold_left[E=E](self._iterator^, initial^, step)

    def fold_left[A: Movable & Deinitable, F: Binary](
        deinit self, step: F, var initial: A
    ) raises F.Error -> A where F.First == A and F.Second == Self.I.Element and F.Out == A:
        """Fold with a library `Binary` step."""
        return _fold_left(self._iterator^, initial^, step)

    def fold_until[A: Movable & Deinitable, Q: Movable & Deinitable,
                   T: Movable & Deinitable, //,
                   F: def(var A, var T) -> ControlFlow[Q, A], B: Movable & Deinitable = Q](
        deinit self, step: F, var initial: A
    ) -> ControlFlow[B, A] where Self.I.Element == T and Q == B:
        """Fold until `Break`, or return `Continue` with the final accumulator.

        A break returns immediately without another pull. Empty input returns
        `Continue(initial)`. Raising overloads preserve the step's error as a
        separate outcome from a `Break`. Library `Binary` steps are also accepted.

        Parameters:
            A: The accumulator type.
            Q: The callback's break payload type, inferred with its origins.
            T: The source element type.
            F: The native step type.
            B: The requested break payload type; defaults to `Q` and must match it.

        Args:
            step: The step returning `ControlFlow[B, A]`, borrowed.
            initial: The initial accumulator, consumed.

        Returns:
            The first `Break`, or `Continue` with the final accumulator.
        """
        return _fold_until[B=B](self._iterator^, initial^, step)

    def fold_until[A: Movable & Deinitable, Q: Movable & Deinitable,
                   T: Movable & Deinitable, E: Movable & Deinitable, //,
                   F: def(var A, var T) raises E -> ControlFlow[Q, A], B: Movable & Deinitable = Q](
        deinit self, step: F, var initial: A
    ) raises E -> ControlFlow[B, A] where Self.I.Element == T and Q == B:
        """Fold until `Break` with a raising step, preserving its error."""
        return _fold_until[E=E, B=B](self._iterator^, initial^, step)

    def fold_until[B: Movable & Deinitable, A: Movable & Deinitable, F: Binary](
        deinit self, step: F, var initial: A
    ) raises F.Error -> ControlFlow[B, A] where F.First == A and F.Second == Self.I.Element and F.Out == ControlFlow[B, A]:
        """Fold until `Break` with a library `Binary` step."""
        return _fold_until[B=B](self._iterator^, initial^, step)

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
        return _reduce(self._iterator^, step)

    def reduce[T: Movable & Deinitable, E: Movable & Deinitable, //,
               F: def(var T, var T) raises E -> T](
        deinit self, step: F
    ) raises ReductionError[E] -> T where Self.I.Element == T:
        """Reduce with a raising step, distinguishing step failure from empty input."""
        return _reduce[E=E](self._iterator^, step)

    def reduce[F: Binary](deinit self, step: F
    ) raises _ReductionFailure[F.Error] -> F.Out where F.First == F.Out and F.Second == F.Out and Self.I.Element == F.Out:
        """Reduce from the first element with a library `Binary` step."""
        return _reduce(self._iterator^, step)

    def reduce[A: Movable & Deinitable, T: Movable & Deinitable, //,
               F: def(var A, var T) -> A](
        deinit self, step: F, *, var initial: A
    ) -> A where Self.I.Element == T:
        """Reduce from an explicit initial accumulator, as `fold_left` does."""
        return _reduce(self._iterator^, step, initial=initial^)

    def reduce[A: Movable & Deinitable, T: Movable & Deinitable,
               E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](
        deinit self, step: F, *, var initial: A
    ) raises E -> A where Self.I.Element == T:
        """Reduce from an initial accumulator, preserving the step's error."""
        return _reduce[E=E](self._iterator^, step, initial=initial^)

    def reduce[A: Movable & Deinitable, F: Binary](
        deinit self, step: F, *, var initial: A
    ) raises F.Error -> A where F.First == A and F.Second == Self.I.Element and F.Out == A:
        """Reduce from an initial accumulator with a library `Binary` step."""
        return _reduce(self._iterator^, step, initial=initial^)

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
        return _reduce_optional(self._iterator^, step)

    def reduce_optional[T: Movable & Deinitable, E: AnyType, //,
                        F: def(var T, var T) raises E -> T](
        deinit self, step: F
    ) raises E -> Optional[T] where Self.I.Element == T:
        """Reduce with a raising step; only empty input becomes `None`."""
        return _reduce_optional[E=E](self._iterator^, step)

    def reduce_optional[F: Binary](deinit self, step: F
    ) raises F.Error -> Optional[F.Out] where F.First == F.Out and F.Second == F.Out and Self.I.Element == F.Out:
        """Reduce with a library `Binary` step, returning `None` for empty input."""
        return _reduce_optional(self._iterator^, step)

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
        return _find(self._iterator^, predicate)

    def find[T: Movable & Deinitable, E: Movable & Deinitable, //,
             F: def(T) raises E -> Bool](
        deinit self, predicate: F
    ) raises E -> Optional[T] where Self.I.Element == T:
        """Find with a raising predicate, propagating its exact error."""
        return _find[E=E](self._iterator^, predicate)

    def find[T: Movable & Deinitable, E: Movable & Deinitable, //](
        deinit self, predicate: def(T) raises E thin -> Bool
    ) raises E -> Optional[T] where Self.I.Element == T:
        """Preserve a plain raising predicate, including explicitly bound Never."""
        return _find[E=E](self._iterator^, predicate)

    def find[C: BorrowCallable](deinit self, predicate: C
    ) raises C.Failure -> Optional[Self.I.Element] where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool:
        """Find with a library borrowing predicate."""
        return _find(self._iterator^, predicate)

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
        return _any(self._iterator^, predicate)

    def any[T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(T) raises E -> Bool](
        deinit self, predicate: F
    ) raises E -> Bool where Self.I.Element == T:
        """Test any element with a raising predicate, preserving its error."""
        return _any[E=E](self._iterator^, predicate)

    def any[T: Movable & Deinitable, E: Movable & Deinitable, //](
        deinit self, predicate: def(T) raises E thin -> Bool
    ) raises E -> Bool where Self.I.Element == T:
        """Preserve a plain raising predicate, including explicitly bound Never."""
        return _any[E=E](self._iterator^, predicate)

    def any[C: BorrowCallable](deinit self, predicate: C
    ) raises C.Failure -> Bool where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool:
        """Test any element with a library borrowing predicate."""
        return _any(self._iterator^, predicate)

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
        return _all(self._iterator^, predicate)

    def all[T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(T) raises E -> Bool](
        deinit self, predicate: F
    ) raises E -> Bool where Self.I.Element == T:
        """Test every element with a raising predicate, preserving its error."""
        return _all[E=E](self._iterator^, predicate)

    def all[T: Movable & Deinitable, E: Movable & Deinitable, //](
        deinit self, predicate: def(T) raises E thin -> Bool
    ) raises E -> Bool where Self.I.Element == T:
        """Preserve a plain raising predicate, including explicitly bound Never."""
        return _all[E=E](self._iterator^, predicate)

    def all[C: BorrowCallable](deinit self, predicate: C
    ) raises C.Failure -> Bool where conforms_to(Self.I.Element, Movable & Deinitable) and C.Payload == Self.I.Element and C.Result == Bool:
        """Test every element with a library borrowing predicate."""
        return _all(self._iterator^, predicate)


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
