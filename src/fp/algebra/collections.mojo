"""Native collection adapters for container-preserving pipeline mapping and filtering.

Sequence families support explicit public selection. Dict and StringDict do
not expose their value parameter through a trait: pipeline_values infers it
once, then operation family projections rebind it after type-changing maps.
Traversal, callback receivers and native error propagation keep their existing
owners; only construction and insertion differ between containers here.
"""
from std.builtin.rebind import rebind_var
from std.collections import Array, Deque, LinkedList, StringDict, KeyElement
from std.collections.dict import DictEntry
from std.hash import Hasher, default_comp_time_hasher
from std.memory import MaybeUninit
from fp._internal.native_collections import _empty_deque_like, _take_string_dict, _string_dict_from_native
from fp.callables.products import _take_pair
from fp.callables.protocols import BorrowCallContract, UnaryContract, Unary, MutableUnary, BorrowCallable
from fp.callables.invoke import call_repeated, RepeatableUnary
from .protocols import Functor, RebindingFunctor, Filterable, FunctorFilter, _Accumulate, _map_accumulate
from .filtering import _Select, _Keep
from .instances import _ListElement, ListFamily
from fp.iteration._advance import _next_optional, _buffer_owned
from fp.iteration.reductions import _Terminal
from fp.iteration.adapters import map as _lazy_map


comptime ArrayFamily[N: Int] = _ArrayFamily[N]
"""Map a native Array's elements, preserving its length and order.

Select with `pipeline(values^).elements()` or name `ArrayFamily[N]` explicitly.
Mapping can change the element
type and moves each element; it requires a repeatable callback. This family
implements Functor only: fixed length does not support filtering or flat_map.
The existing Array mapping boundary uses O(N) temporary storage on Mojo 1.2.

Parameters:
    N: The Array's fixed length.
"""

comptime DequeFamily = _DequeFamily
"""Map and filter native Deque elements, preserving their order and settings.

Select with `pipeline(values^).elements()` or name `DequeFamily` explicitly.
Mapping and filter_map can change
the element type. Callbacks are repeatable and elements are moved. The family
implements Functor, Filterable and FunctorFilter, without Applicative or Monad.
"""

comptime LinkedListFamily = _LinkedListFamily
"""Map and filter native LinkedList elements in their original order.

Select with `pipeline(values^).elements()` or name `LinkedListFamily` explicitly.
Mapping and filter_map can
change the element type. Callbacks are repeatable and elements are moved. The
family implements Functor, Filterable and FunctorFilter, without Applicative
or Monad.
"""


struct _ArrayFamily[N: Int](Functor):
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == Array[F.Arg, Self.N]
    comptime Element[V: Movable & Deinitable] = _ListElement[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Array[F.Out, Self.N]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        comptime assert V == Array[F.Arg, Self.N], "map: Array carrier required"
        var source = rebind_var[Array[F.Arg, Self.N]](value^)
        # Mojo 1.2's owning Array iterator destroys its source slots when it is
        # moved (covered by drop-count tests). Drain the iterator in place.
        # Buffer through ListFamily instead of copying values
        # or reproducing its callback/error loop. Cost: O(N) temporary storage.
        var items = _take_array(source^)
        var mapped = ListFamily.map(f^, items^)
        var iterator = iter(mapped^)
        # Mapping kept the length, so every constructor call has an element.
        def take_next(i: Int) {ref iterator} -> F.Out:
            var next = _next_optional[F.Out](iterator)
            return next.unsafe_take()
        return Array[F.Out, Self.N](fill_with=take_next)



struct _DequeAppend[T: Movable & Deinitable](_Accumulate):
    comptime Acc = Deque[Self.T]
    comptime Item = Self.T
    @staticmethod
    def start() -> Self.Acc:
        return Self.Acc()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) -> Self.Acc:
        acc.append(item^)
        return acc^


struct _DequeFamily(Functor, Filterable, FunctorFilter):
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == Deque[F.Arg]
    comptime Element[V: Movable & Deinitable] = _ListElement[V]
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P.Failure
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Deque[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Deque[_ListElement[F.Out]]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.MapFiltered[V, F]:
        comptime U = _ListElement[F.Out]
        comptime assert F.Out == Optional[U], "filter_map: Optional result required"
        comptime assert V == Deque[F.Arg]
        return _deque_accumulate[F.Arg, U, F, _Keep[_DequeAppend[U]]](f^, rebind_var[Deque[F.Arg]](value^))

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        comptime assert V == Deque[F.Arg], "map: Deque carrier required"
        return _deque_accumulate[F.Arg, F.Out, F, _DequeAppend[F.Out]](
            f^, rebind_var[Deque[F.Arg]](value^))

    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V
    ) raises P.Failure -> V:
        """Retain accepted deque elements, keeping the native settings."""
        comptime T = Self.Element[V]
        comptime assert P.Payload == T and P.Result == Bool
        return rebind_var[V](Self.filter_map(_Select[T, P](predicate^), value^))


def _deque_accumulate[T: Movable & Deinitable, U: Movable & Deinitable,
                      F: UnaryContract & Movable & Deinitable, K: _Accumulate](
    var f: F, var source: Deque[T]
) raises F.Error -> Deque[U]:
    comptime assert K.Acc == Deque[U] and K.Error == Never
    var result = _empty_deque_like[T, U](source)
    return rebind_var[Deque[U]](_map_accumulate[Deque[T], F, K, F.Error](
        f^, source^, rebind_var[K.Acc](result^)))



struct _LinkedAppend[T: Movable & Deinitable](_Accumulate):
    comptime Acc = LinkedList[Self.T]
    comptime Item = Self.T
    @staticmethod
    def start() -> Self.Acc:
        return Self.Acc()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) -> Self.Acc:
        acc.append(item^)
        return acc^


struct _LinkedListFamily(Functor, Filterable, FunctorFilter):
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == LinkedList[F.Arg]
    comptime Element[V: Movable & Deinitable] = _ListElement[V]
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P.Failure
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = LinkedList[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = LinkedList[_ListElement[F.Out]]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.MapFiltered[V, F]:
        comptime U = _ListElement[F.Out]
        comptime assert F.Out == Optional[U], "filter_map: Optional result required"
        comptime assert V == LinkedList[F.Arg]
        return _map_accumulate[V, F, _Keep[_LinkedAppend[U]], F.Error](f^, value^, LinkedList[U]())

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        comptime assert V == LinkedList[F.Arg], "map: LinkedList carrier required"
        return _map_accumulate[LinkedList[F.Arg], F, _LinkedAppend[F.Out], F.Error](
            f^, rebind_var[LinkedList[F.Arg]](value^), LinkedList[F.Out]())

    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V
    ) raises P.Failure -> V:
        """Retain accepted linked-list elements in their original order."""
        comptime T = Self.Element[V]
        comptime assert P.Payload == T and P.Result == Bool
        return rebind_var[V](Self.filter_map(_Select[T, P](predicate^), value^))


@fieldwise_init
struct _EntryValues[K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, F: UnaryContract & Movable & Deinitable](MutableUnary):
    var function: Self.F
    comptime Arg = DictEntry[Self.K, Self.F.Arg, Self.H]
    comptime Out = Tuple[Self.K, Self.F.Out]
    comptime Error = Self.F.Error
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F], "Dict callbacks must be repeatable"
        var key_slot = MaybeUninit[Self.K]()
        var value_slot = MaybeUninit[Self.F.Arg]()
        _take_entry(arg^, key_slot, value_slot)
        var key = key_slot^.unsafe_assume_init()
        var value = value_slot^.unsafe_assume_init()
        var mapped = call_repeated(self.function, value^)
        return (key^, mapped^)


struct _DictInsert[K: KeyElement & Deinitable, T: Movable & Deinitable, H: Hasher & Defaultable & Deinitable](_Accumulate):
    comptime Acc = Dict[Self.K, Self.T, Self.H]
    comptime Item = Tuple[Self.K, Self.T]
    @staticmethod
    def start() -> Self.Acc:
        return Self.Acc()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) -> Self.Acc:
        var key_slot = MaybeUninit[Self.K]()
        var value_slot = MaybeUninit[Self.T]()
        _take_pair(item^, key_slot, value_slot)
        var key = key_slot^.unsafe_assume_init()
        var value = value_slot^.unsafe_assume_init()
        acc[key^] = value^
        return acc^


struct _DictFamily[K: KeyElement & Deinitable, A: Movable & Deinitable, H: Hasher & Defaultable & Deinitable](RebindingFunctor, Filterable, FunctorFilter):
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == Dict[Self.K, Self.A, Self.H] and F.Arg == Self.A
    comptime WithElement[A: Movable & Deinitable] = _DictFamily[Self.K, A, Self.H]
    comptime Element[V: Movable & Deinitable] = Self.A
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P.Failure
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Dict[Self.K, F.Out, Self.H]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Dict[Self.K, _ListElement[F.Out], Self.H]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.MapFiltered[V, F]:
        comptime U = _ListElement[F.Out]
        comptime assert F.Out == Optional[U], "filter_map: Optional result required"
        comptime assert V == Dict[Self.K, F.Arg, Self.H] and Self.A == F.Arg
        comptime C = _FilterValues[Self.K, U, Self.H, F]
        return _dict_accumulate[Self.K, F.Arg, U, Self.H, C, _Keep[_DictInsert[Self.K, U, Self.H]]](
            C(_EntryValues[Self.K, Self.H, F](f^)), rebind_var[Dict[Self.K, F.Arg, Self.H]](value^))

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        comptime assert V == Dict[Self.K, F.Arg, Self.H] and Self.A == F.Arg, "map: Dict carrier required"
        comptime C = _EntryValues[Self.K, Self.H, F]
        return _dict_accumulate[Self.K, F.Arg, F.Out, Self.H, C, _DictInsert[Self.K, F.Out, Self.H]](
            C(f^), rebind_var[Dict[Self.K, F.Arg, Self.H]](value^))

    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V
    ) raises P.Failure -> V:
        """Filter dictionary values, retaining accepted keys and insertion order."""
        comptime T = Self.Element[V]
        comptime assert P.Payload == T and P.Result == Bool
        return rebind_var[V](Self.filter_map(_Select[T, P](predicate^), value^))


def _dict_accumulate[K: KeyElement & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable,
                     H: Hasher & Defaultable & Deinitable, F: UnaryContract & Movable & Deinitable, S: _Accumulate](
    var f: F, var source: Dict[K, A, H]
) raises F.Error -> Dict[K, B, H]:
    comptime assert S.Acc == Dict[K, B, H] and S.Error == Never
    var result = Dict[K, B, H](capacity=len(source))
    # Native take_items drains in insertion order, preserving move-only keys and
    # values. Dict's owning key iterator would discard the values.
    var entries = source.take_items()
    return rebind_var[Dict[K, B, H]](_map_accumulate[type_of(entries), F, S, F.Error](
        f^, entries^, rebind_var[S.Acc](result^)))


def _take_entry[K: KeyElement & Deinitable, T: Movable & Deinitable, H: Hasher & Defaultable & Deinitable](
    var entry: DictEntry[K, T, H], mut key: MaybeUninit[K], mut value: MaybeUninit[T]
):
    def take(var k: K, var v: T) {ref key, ref value}:
        key.unsafe_write(k^)
        value.unsafe_write(v^)
    entry^.deinit_with(take)


struct _StringDictFamily[A: Movable & Deinitable](RebindingFunctor, Filterable, FunctorFilter):
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = V == StringDict[Self.A] and F.Arg == Self.A
    comptime WithElement[A: Movable & Deinitable] = _StringDictFamily[A]
    comptime Element[V: Movable & Deinitable] = Self.A
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P.Failure
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = StringDict[F.Out]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = StringDict[_ListElement[F.Out]]
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.MapFiltered[V, F]:
        comptime U = _ListElement[F.Out]
        comptime assert F.Out == Optional[U], "filter_map: Optional result required"
        comptime assert V == StringDict[Self.A] and F.Arg == Self.A
        var native = _take_string_dict(rebind_var[StringDict[Self.A]](value^))
        return _string_dict_from_native(_DictFamily[String, Self.A, default_comp_time_hasher].filter_map(f^, native^))

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises F.Error -> Self.Mapped[V, F]:
        comptime assert V == StringDict[F.Arg] and Self.A == F.Arg, "map: StringDict carrier required"
        var source = rebind_var[StringDict[F.Arg]](value^)
        var native = _take_string_dict(source^)
        return _string_dict_from_native(_DictFamily[String, F.Arg, default_comp_time_hasher].map(f^, native^))

    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V
    ) raises P.Failure -> V:
        """Filter keyword dictionary values through the native Dict adapter."""
        comptime T = Self.Element[V]
        comptime assert P.Payload == T and P.Result == Bool
        return rebind_var[V](Self.filter_map(_Select[T, P](predicate^), value^))



@fieldwise_init
struct _FilterValues[K: KeyElement & Deinitable, U: Movable & Deinitable, H: Hasher & Defaultable & Deinitable,
                     F: UnaryContract & Movable & Deinitable](MutableUnary):
    var entry: _EntryValues[Self.K, Self.H, Self.F]
    comptime Arg = DictEntry[Self.K, Self.F.Arg, Self.H]
    comptime Out = Optional[Tuple[Self.K, Self.U]]
    comptime Error = Self.F.Error
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.F.Out == Optional[Self.U]
        var mapped = self.entry.call_mut(arg^)
        var key_slot = MaybeUninit[Self.K]()
        var value_slot = MaybeUninit[Optional[Self.U]]()
        _take_pair(rebind_var[Tuple[Self.K, Optional[Self.U]]](mapped^), key_slot, value_slot)
        var key = key_slot^.unsafe_assume_init()
        var present = value_slot^.unsafe_assume_init()
        if present:
            return Optional((key^, present.unsafe_take()))
        return None


def _take_array[T: Movable & Deinitable, N: Int](var source: Array[T, N]) -> List[T]:
    # One workaround for the pinned owning Array iterator, shared by mapping
    # and terminal operations. Elements are moved, including move-only values.
    return _buffer_owned(source^)


@fieldwise_init
struct _EntryPayload[K: KeyElement & Deinitable, T: Movable & Deinitable, H: Hasher & Defaultable & Deinitable](Unary):
    comptime Arg = DictEntry[Self.K, Self.T, Self.H]
    comptime Out = Self.T
    def call(self, var arg: Self.Arg) -> Self.T:
        var key_slot = MaybeUninit[Self.K]()
        var value_slot = MaybeUninit[Self.T]()
        _take_entry(arg^, key_slot, value_slot)
        var key = key_slot^.unsafe_assume_init()
        _ = key^
        return value_slot^.unsafe_assume_init()


def _dict_terminal[K: KeyElement & Deinitable, T: Movable & Deinitable, H: Hasher & Defaultable & Deinitable, R: _Terminal](
    var reduction: R, var source: Dict[K, T, H]
) raises R.Error -> R.Out:
    # take_items borrows local storage. Run the terminal before that storage
    # dies; a returned iterator would let this borrow escape. The generic run
    # method preserves the view's native origin without erasing it.
    var entries = source.take_items()
    var values = _lazy_map(_EntryPayload[K, T, H](), entries^)
    return reduction^.run(values^)


def _string_dict_terminal[T: Movable & Deinitable, R: _Terminal](
    var reduction: R, var source: StringDict[T]
) raises R.Error -> R.Out:
    return _dict_terminal(reduction^, _take_string_dict(source^))


def _array_terminal[T: Movable & Deinitable, N: Int, R: _Terminal](
    var reduction: R, var source: Array[T, N]
) raises R.Error -> R.Out:
    return reduction^.run(_take_array(source^))
