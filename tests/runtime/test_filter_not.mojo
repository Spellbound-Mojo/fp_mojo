"""Derived rejection filtering preserves carrier, timing, errors and ownership."""
from std.collections import Deque, LinkedList, StringDict
from std.hash import default_comp_time_hasher
from std.memory import ArcPointer
from std.iter import Iterator, IterableOwned
from std.testing import assert_equal
from fp.functions import Piped, piped
from fp.iteration import iterated, collect_list
from fp.combinators import filter_not
from fp.algebra import filter_not as family_filter_not, ListFamily
from test_container_filter import (ContainerFilterBox, ContainerFilterFamily,
    ContainerFilterPredicate, ContainerFilterRaisingPredicate, ContainerFilterFailure, ContainerDeferredFamily)
from test_container_map import ContainerMapItem, ContainerMapKey


def filter_not_positive(value: Int) -> Bool: return value > 0

def filter_not_shapes() raises:
    var calls = 0
    var seen = List[Int]()
    def filter_not_counted(value: Int) {mut calls, ref seen} -> Bool:
        calls += 1
        seen.append(value)
        return value > 0
    var stage = piped(List[Int]([-1, 2, -3])).filter_not(filter_not_counted)
    comptime assert type_of(stage) == Piped[List[Int]]
    assert_equal(calls, 3)
    assert_equal(seen, [-1, 2, -3])
    assert_equal(stage^.get(), [-1, -3])
    assert_equal(filter_not_counted(1), True)  # Eager callback is still usable.
    _ = piped(List[Int]()).filter_not(filter_not_counted).get()
    _ = piped(Optional[Int]()).filter_not(filter_not_counted).get()
    assert_equal(calls, 4)
    assert_equal(piped(List[Int]([1, 2])).filter_not(filter_not_positive).get(), List[Int]())
    assert_equal(piped(List[Int]([-1, 0])).filter_not(filter_not_positive).get(), [-1, 0])
    var deque = Deque[Int](capacity=8, min_capacity=4, maxlen=2, shrink=False)
    deque.append(-1)
    deque.append(2)
    var kept_deque = piped(deque^).filter_not(filter_not_positive).get()
    comptime assert type_of(kept_deque) == Deque[Int]
    assert_equal(kept_deque._min_capacity, 4)
    assert_equal(kept_deque._shrink, False)
    kept_deque.append(-2)
    kept_deque.append(-3)
    assert_equal(collect_list(kept_deque^), [-2, -3])
    var linked = LinkedList[Int]()
    linked.append(-1)
    linked.append(2)
    var kept_linked = piped(linked^).filter_not(filter_not_positive).get()
    comptime assert type_of(kept_linked) == LinkedList[Int]
    assert_equal(collect_list(kept_linked^), [-1])
    var dict = Dict[String, Int, default_comp_time_hasher]()
    dict["b"] = -1
    dict["a"] = 2
    dict["c"] = -3
    var kept_dict = piped(dict^).filter_not(filter_not_counted).get()
    comptime assert type_of(kept_dict) == Dict[String, Int, default_comp_time_hasher]
    assert_equal(kept_dict["b"], -1)
    assert_equal(collect_list(kept_dict^), ["b", "c"])
    assert_equal(calls, 7)
    var kw = StringDict[Int]()
    kw["x"] = -1
    kw["y"] = 2
    var kept_kw = piped(kw^).filter_not(filter_not_positive).get()
    comptime assert type_of(kept_kw) == StringDict[Int]
    assert_equal(len(kept_kw), 1)
    assert_equal(kept_kw["x"], -1)
    var some = piped(Optional(-1)).filter_not(filter_not_positive).get()
    comptime assert type_of(some) == Optional[Int]
    assert_equal(some.take(), -1)
    assert_equal(Bool(piped(Optional(1)).filter_not(filter_not_positive).get()), False)


def filter_not_library_shapes() raises:
    var calls = ArcPointer(0)
    assert_equal(piped(List[Int]([-1, 2])).filter_not(ContainerFilterPredicate(calls)).get(), [-1])
    var deque = Deque[Int]()
    deque.append(-1)
    deque.append(2)
    assert_equal(collect_list(piped(deque^).filter_not(ContainerFilterPredicate(calls)).get()), [-1])
    var linked = LinkedList[Int]()
    linked.append(-1)
    linked.append(2)
    assert_equal(collect_list(piped(linked^).filter_not(ContainerFilterPredicate(calls)).get()), [-1])
    var dict = Dict[String, Int, default_comp_time_hasher]()
    dict["b"] = -1
    dict["a"] = 2
    var kept_dict = piped(dict^).filter_not(ContainerFilterPredicate(calls)).get()
    comptime assert type_of(kept_dict) == Dict[String, Int, default_comp_time_hasher]
    assert_equal(collect_list(kept_dict^), ["b"])
    var kw = StringDict[Int]()
    kw["x"] = -1
    kw["y"] = 2
    var kept_kw = piped(kw^).filter_not(ContainerFilterPredicate(calls)).get()
    assert_equal(kept_kw["x"], -1)
    assert_equal(len(kept_kw), 1)
    var some = piped(Optional(-1)).filter_not(ContainerFilterPredicate(calls)).get()
    assert_equal(some.take(), -1)
    assert_equal(calls[], 11)


@fieldwise_init
struct FilterNotOrdinary(Movable):
    var value: Int

def filter_not_extract(var value: FilterNotOrdinary) -> List[Int]:
    return List[Int]([-value.value, value.value])
def filter_not_size(var values: List[Int]) -> Int: return len(values)

def filter_not_families() raises:
    var ordinary: Piped[FilterNotOrdinary] = piped(FilterNotOrdinary(2))
    var scalar: Piped[Int] = ordinary^.then(filter_not_extract).filter_not(filter_not_positive).then(filter_not_size)
    assert_equal(scalar^.get(), 1)
    var custom = piped(ContainerFilterBox(List[Int]([-1, 2]))).filter_not[ContainerFilterFamily](filter_not_positive).get()
    assert_equal(custom.values, [-1])
    var calls = ArcPointer(0)
    var owned_custom = piped(ContainerFilterBox(List[Int]([-1, 2]))).filter_not[ContainerFilterFamily](ContainerFilterPredicate(calls)).get()
    assert_equal(owned_custom.values, [-1])
    var deferred = piped(List[Int]([-1, 2])).filter_not[ContainerDeferredFamily](ContainerFilterPredicate(calls)).get()
    assert_equal(calls[], 2)
    assert_equal(deferred^.run(), [-1])
    assert_equal(calls[], 4)
    var native_calls = 0
    def filter_not_deferred_native(value: Int) {mut native_calls} -> Bool:
        native_calls += 1
        return value > 0
    var native_deferred = piped(List[Int]([-1, 2])).filter_not[ContainerDeferredFamily](filter_not_deferred_native).get()
    assert_equal(native_calls, 0)
    assert_equal(native_deferred^.run(), [-1])
    assert_equal(native_calls, 2)
    assert_equal(filter_not_deferred_native(1), True)
    assert_equal(family_filter_not[ListFamily](List[Int]([-1, 2]), filter_not_positive), [-1])
    assert_equal(family_filter_not[ListFamily](List[Int]([-1, 2]), ContainerFilterPredicate(calls)), [-1])


def filter_not_lazy() raises:
    var calls = 0
    def filter_not_lazy_counted(value: Int) {mut calls} -> Bool:
        calls += 1
        return value > 0
    var lazy = iterated(List[Int]([-1, 2, -3])).filter_not(filter_not_lazy_counted)
    assert_equal(calls, 0)
    assert_equal(next(lazy), -1)
    assert_equal(calls, 1)
    assert_equal(lazy^.collect_list(), [-3])
    assert_equal(calls, 3)
    assert_equal(collect_list(filter_not(range(3), filter_not_positive)), [0])
    assert_equal(collect_list(filter_not(range(3), filter_not_lazy_counted)), [0])
    assert_equal(calls, 6)
    var library_calls = ArcPointer(0)
    assert_equal(iterated(range(3)).filter_not(ContainerFilterPredicate(library_calls)).collect_list(), [0])
    assert_equal(collect_list(filter_not(range(3), ContainerFilterPredicate(library_calls))), [0])
    assert_equal(library_calls[], 6)
    var state_drops = ArcPointer(0)
    var filter_not_state = ContainerMapItem(0, state_drops)
    def filter_not_owned(value: Int) {var filter_not_state^} -> Bool:
        filter_not_state.value += 1
        return filter_not_state.value % 2 == 0
    assert_equal(iterated(range(5)).filter_not(filter_not_owned^).collect_list(), [0, 2, 4])
    assert_equal(state_drops[], 1)
    var filter_not_borrowed_state = ContainerMapItem(0, state_drops)
    def filter_not_borrowed_owned(value: Int) {var filter_not_borrowed_state^} -> Bool:
        filter_not_borrowed_state.value += 1
        return filter_not_borrowed_state.value % 2 == 0
    assert_equal(piped(List[Int]([0, 1, 2])).filter_not(filter_not_borrowed_owned).get(), [0, 2])
    assert_equal(filter_not_borrowed_owned(3), True)
    _ = filter_not_borrowed_owned^
    assert_equal(state_drops[], 2)


@fieldwise_init
struct FilterNotRestarting(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var calls: ArcPointer[Int]
    def __iter__(var self) -> Self: return self^
    def __next__(mut self) raises StopIteration -> Int:
        self.calls[] += 1
        if self.calls[] == 2: raise StopIteration()
        return -self.calls[]

def filter_not_fusion() raises:
    var pulls = ArcPointer(0)
    var lazy = iterated(FilterNotRestarting(pulls)).filter_not(filter_not_positive)
    assert_equal(pulls[], 0)
    assert_equal(next(lazy), -1)
    for _ in range(2):
        var ended = False
        try: _ = next(lazy)
        except: ended = True
        assert_equal(ended, True)
    assert_equal(pulls[], 2)
    var position = iter(range(-2, 2))
    assert_equal(next(position), -2)
    assert_equal(iterated(position).filter_not(filter_not_positive).collect_list(), [-1, 0])


def filter_not_ownership() raises:
    var drops = ArcPointer(0)
    def filter_not_reject_item(value: ContainerMapItem) -> Bool: return value.value > 0
    var values: List[ContainerMapItem] = [ContainerMapItem(-1, drops), ContainerMapItem(2, drops)]
    var kept = piped(values^).filter_not(filter_not_reject_item).get()
    assert_equal(drops[], 1)
    assert_equal(kept[0].value, -1)
    _ = kept^
    assert_equal(drops[], 2)
    var keys = ArcPointer(0)
    var dict = Dict[ContainerMapKey, ContainerMapItem]()
    dict[ContainerMapKey(0, keys)] = ContainerMapItem(-1, drops)
    dict[ContainerMapKey(1, keys)] = ContainerMapItem(2, drops)
    var kept_dict = piped(dict^).filter_not(filter_not_reject_item).get()
    assert_equal(drops[], 3)
    assert_equal(keys[], 1)
    _ = kept_dict^
    assert_equal(drops[], 4)
    assert_equal(keys[], 2)
    var more: List[ContainerMapItem] = [ContainerMapItem(-1, drops), ContainerMapItem(2, drops)]
    var lazy = iterated(more^).filter_not(filter_not_reject_item)
    var first = next(lazy)
    _ = lazy^
    assert_equal(drops[], 5)
    assert_equal(first.value, -1)
    _ = first^
    assert_equal(drops[], 6)
    var calls = 0
    var filter_not_unpulled_state = ContainerMapItem(0, drops)
    def filter_not_unpulled(value: Int) {var filter_not_unpulled_state^, mut calls} -> Bool:
        calls += 1
        return value > filter_not_unpulled_state.value
    var untouched = iterated(range(3)).filter_not(filter_not_unpulled^)
    _ = untouched^
    assert_equal(calls, 0)
    assert_equal(drops[], 7)


def filter_not_errors() raises:
    var calls = 0
    def filter_not_checked(value: Int) raises ContainerFilterFailure {mut calls} -> Bool:
        calls += 1
        if value == 2: raise ContainerFilterFailure(value)
        return value > 0
    var failed = False
    try:
        _ = piped(List[Int]([-1, 2, 3])).filter_not(filter_not_checked).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        failed = error.at == 2
    assert_equal(failed, True)
    assert_equal(calls, 2)
    def filter_not_stop(value: Int) raises StopIteration -> Bool:
        raise StopIteration()
    failed = False
    try: _ = piped(Optional(1)).filter_not(filter_not_stop).get()
    except error:
        comptime assert type_of(error) == StopIteration
        failed = True
    assert_equal(failed, True)
    failed = False
    try: _ = piped(Optional(7)).filter_not(ContainerFilterRaisingPredicate()).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        failed = error.at == 7
    assert_equal(failed, True)
    var deferred = piped(List[Int]([2])).filter_not[ContainerDeferredFamily](filter_not_checked).get()
    assert_equal(calls, 2)
    failed = False
    try: _ = deferred^.run()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        failed = error.at == 2
    assert_equal(failed, True)
    assert_equal(calls, 3)
    var drops = ArcPointer(0)
    def filter_not_fail_item(value: ContainerMapItem) raises ContainerFilterFailure -> Bool:
        if value.value == 2: raise ContainerFilterFailure(2)
        return value.value > 0
    var items: List[ContainerMapItem] = [ContainerMapItem(-1, drops), ContainerMapItem(1, drops), ContainerMapItem(2, drops), ContainerMapItem(3, drops)]
    failed = False
    try: _ = piped(items^).filter_not(filter_not_fail_item).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        failed = True
    assert_equal(failed, True)
    assert_equal(drops[], 4)


def filter_not_origins(anchor: List[Int]) raises:
    var views: List[Span[Int, origin_of(anchor)]] = [Span(anchor)]
    def filter_not_empty(value: Span[Int, origin_of(anchor)]) {anchor} -> Bool:
        return len(value) == 0
    var kept = piped(views^).filter_not(filter_not_empty).get()
    assert_equal(kept[0][0], 11)
    assert_equal(iterated(iter(kept)).filter_not(filter_not_empty).collect_list()[0][1], 12)


def main() raises:
    filter_not_shapes()
    filter_not_library_shapes()
    filter_not_families()
    filter_not_lazy()
    filter_not_fusion()
    filter_not_ownership()
    filter_not_errors()
    filter_not_origins([11, 12])
    print("filter_not: eager and lazy contracts preserved")
