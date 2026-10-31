"""Eager filtering preserves containers, borrowed payloads and exact failures."""
from fp.callables import BorrowCallContract
from std.builtin.rebind import rebind_var, downcast
from std.collections import Deque, LinkedList, StringDict
from std.hash import default_comp_time_hasher
from std.memory import ArcPointer
from std.testing import assert_equal
from fp.functions import pipeline, pipeline_values, Pipeline
from fp.iteration import collect_list, iterated
from fp.algebra import Filterable, ListFamily, OptionalFamily, filter
from fp.callables import BorrowCallable
from test_container_map import ContainerMapItem, ContainerMapKey


def filter_positive(value: Int) -> Bool: return value > 0
def filter_square(value: Int) -> Int: return value * value

@fieldwise_init
struct ContainerFilterFailure(Movable):
    var at: Int

@fieldwise_init
struct ContainerFilterPredicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    var calls: ArcPointer[Int]
    def invoke(self, ref payload: Int) capturing -> Bool:
        self.calls[] += 1
        return payload > 0

@fieldwise_init
struct ContainerFilterRaisingPredicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = ContainerFilterFailure
    def invoke(self, ref payload: Int) raises Self.Failure capturing -> Bool:
        raise ContainerFilterFailure(payload)


trait ContainerFilterCarrier:
    comptime Element: Movable & Deinitable

@fieldwise_init
struct ContainerFilterBox[T: Movable & Deinitable](Movable, ContainerFilterCarrier):
    comptime Element = Self.T
    var values: List[Self.T]
    def take(deinit self) -> List[Self.T]:
        return self.values^

struct ContainerFilterFamily(Filterable):
    comptime Element[V: Movable & Deinitable] = downcast[V, ContainerFilterCarrier].Element
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = V
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable] = P.Failure
    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V) raises P.Failure -> V:
        comptime T = Self.Element[V]
        comptime assert V == ContainerFilterBox[T]
        var box = rebind_var[ContainerFilterBox[T]](value^)
        var kept = ListFamily.filter(predicate^, box^.take())
        return rebind_var[V](ContainerFilterBox(kept^))


def filter_forward[T: Movable & Deinitable, //, F: def(T) -> Bool](
    ref predicate: F, var source: List[T]
) -> List[T]:
    return pipeline[ListFamily](source^).filter(predicate).get()


def filter_forward_raised[T: Movable & Deinitable, E: Movable & Deinitable, //, F: def(T) raises E -> Bool](
    ref predicate: F, var source: List[T]
) raises E -> List[T]:
    return pipeline[ListFamily](source^).raising[E]().filter(predicate).get()


from algebra_support.filtering import ContainerDeferredFamily


def filter_shapes() raises:
    var calls = 0
    var seen = List[Int]()
    def counted(value: Int) {mut calls, ref seen} -> Bool:
        calls += 1
        seen.append(value)
        return value > 0
    var xs: List[Int] = [3, -1, 4, -2, 5]
    var stage = pipeline(xs^).filter(counted)
    comptime assert type_of(stage).V == List[Int]
    assert_equal(calls, 5)
    assert_equal(seen, [3, -1, 4, -2, 5])
    assert_equal(stage^.map(filter_square).get(), [9, 16, 25])
    assert_equal(counted(1), True)  # Eager native callback was borrowed.
    assert_equal(pipeline(List[Int]()).filter(counted).get(), List[Int]())
    assert_equal(calls, 6)
    var rejected: List[Int] = [-1, 0]
    assert_equal(pipeline(rejected^).filter(filter_positive).get(), List[Int]())
    var accepted: List[Int] = [1, 2]
    assert_equal(filter_forward(filter_positive, accepted^), [1, 2])
    var deque = Deque[Int](capacity=8, min_capacity=4, maxlen=3, shrink=False)
    deque.append(3)
    deque.append(-1)
    deque.append(4)
    var kept_deque = pipeline(deque^).elements().filter(filter_positive).get()
    comptime assert type_of(kept_deque) == Deque[Int]
    assert_equal(kept_deque._min_capacity, 4)
    assert_equal(kept_deque._shrink, False)
    kept_deque.append(5)
    kept_deque.append(6)
    assert_equal(collect_list(kept_deque^), [4, 5, 6])
    var linked = LinkedList[Int]()
    linked.append(-1)
    linked.append(7)
    var kept_linked = pipeline(linked^).elements().filter(filter_positive).get()
    comptime assert type_of(kept_linked) == LinkedList[Int]
    assert_equal(collect_list(kept_linked^), [7])
    var dict = Dict[String, Int, default_comp_time_hasher]()
    dict["b"] = 2
    dict["a"] = -1
    dict["c"] = 4
    var kept_dict = pipeline_values(dict^).filter(counted).get()
    comptime assert type_of(kept_dict) == Dict[String, Int, default_comp_time_hasher]
    assert_equal(kept_dict["b"], 2)
    assert_equal(kept_dict["c"], 4)
    assert_equal(collect_list(kept_dict^), ["b", "c"])
    var kw = StringDict[Int]()
    kw["yes"] = 1
    kw["no"] = 0
    var kept_kw = pipeline_values(kw^).filter(filter_positive).get()
    comptime assert type_of(kept_kw) == StringDict[Int]
    assert_equal(len(kept_kw), 1)
    assert_equal(kept_kw["yes"], 1)
    var some = pipeline(Optional(2)).filter(filter_positive).get()
    comptime assert type_of(some) == Optional[Int]
    assert_equal(some.take(), 2)
    assert_equal(Bool(pipeline(Optional(-1)).filter(filter_positive).get()), False)
    assert_equal(Bool(filter[OptionalFamily](Optional[Int](), filter_positive)), False)
    var count_before = calls
    _ = pipeline(Optional[Int]()).filter(counted).get()
    assert_equal(calls, count_before)
    var custom_values: List[Int] = [-1, 2, 3]
    var custom = filter[ContainerFilterFamily](ContainerFilterBox(custom_values^), filter_positive)
    assert_equal(custom.values, [2, 3])
    var library_calls = ArcPointer(0)
    var library_values: List[Int] = [-1, 2]
    assert_equal(pipeline(library_values^).filter(ContainerFilterPredicate(library_calls)).get(), [2])
    assert_equal(library_calls[], 2)
    var lazy_calls = 0
    def lazy_pred(value: Int) {mut lazy_calls} -> Bool:
        lazy_calls += 1
        return value > 0
    var lazy = iterated(range(3)).filter(lazy_pred)
    assert_equal(lazy_calls, 0)
    assert_equal(lazy^.collect_list(), [1, 2])
    assert_equal(lazy_calls, 3)


def filter_library_and_deferred() raises:
    var calls = ArcPointer(0)
    var predicate = ContainerFilterPredicate(calls)
    var deferred = filter[ContainerDeferredFamily](List[Int]([0, 1, 2]), predicate^)
    assert_equal(calls[], 0)
    assert_equal(deferred^.run(), [1, 2])
    assert_equal(calls[], 3)
    var lazy_calls = 0
    def select(value: Int) {mut lazy_calls} -> Bool:
        lazy_calls += 1
        return value > 0
    var native_deferred = filter[ContainerDeferredFamily](List[Int]([0, 1]), select)
    assert_equal(lazy_calls, 0)
    assert_equal(native_deferred^.run(), [1])
    assert_equal(lazy_calls, 2)
    var deque = Deque[Int]()
    deque.append(1)
    assert_equal(collect_list(pipeline(deque^).elements().filter(ContainerFilterPredicate(calls)).get()), [1])
    var linked = LinkedList[Int]()
    linked.append(1)
    assert_equal(collect_list(pipeline(linked^).elements().filter(ContainerFilterPredicate(calls)).get()), [1])
    var dict = Dict[String, Int]()
    dict["a"] = 1
    var kept_dict = pipeline_values(dict^).filter(ContainerFilterPredicate(calls)).get()
    assert_equal(kept_dict["a"], 1)
    var kw = StringDict[Int]()
    kw["a"] = 1
    var kept_kw = pipeline_values(kw^).filter(ContainerFilterPredicate(calls)).get()
    assert_equal(kept_kw["a"], 1)
    var kept = pipeline(Optional(1)).filter(ContainerFilterPredicate(calls)).get()
    assert_equal(kept.take(), 1)
    assert_equal(calls[], 8)
    var drops = ArcPointer(0)
    var state = ContainerMapItem(1, drops)
    def owned(value: Int) {var state^} -> Bool:
        return value > state.value
    assert_equal(pipeline(List[Int]([1, 2])).filter(owned).get(), [2])
    assert_equal(owned(3), True)
    assert_equal(drops[], 0)
    _ = owned^
    assert_equal(drops[], 1)


def filter_moves() raises:
    var drops = ArcPointer(0)
    var visits = ArcPointer(0)
    def keep(value: ContainerMapItem) raises {drops, visits} -> Bool:
        visits[] += 1
        # Rejected values are destroyed before the next predicate runs.
        if value.value == 2:
            assert_equal(drops[], 1)
        return value.value != 1
    var xs: List[ContainerMapItem] = [ContainerMapItem(0, drops), ContainerMapItem(1, drops), ContainerMapItem(2, drops)]
    var kept = pipeline(xs^).raising[Error]().filter(keep).get()
    assert_equal(visits[], 3)
    assert_equal(drops[], 1)
    assert_equal(len(kept), 2)
    assert_equal(kept[1].value, 2)
    _ = kept^
    assert_equal(drops[], 3)
    drops[] = 0
    var keys = ArcPointer(0)
    var dict = Dict[ContainerMapKey, ContainerMapItem]()
    dict[ContainerMapKey(0, keys)] = ContainerMapItem(0, drops)
    dict[ContainerMapKey(1, keys)] = ContainerMapItem(1, drops)
    dict[ContainerMapKey(2, keys)] = ContainerMapItem(2, drops)
    var kept_dict = pipeline_values(dict^).raising[Error]().filter(keep).get()
    assert_equal(drops[], 1)
    assert_equal(keys[], 1)
    assert_equal(len(kept_dict), 2)
    _ = kept_dict^
    assert_equal(drops[], 3)
    assert_equal(keys[], 3)


def filter_errors() raises:
    var calls = 0
    def checked(value: Int) raises ContainerFilterFailure {mut calls} -> Bool:
        calls += 1
        if value == 2: raise ContainerFilterFailure(value)
        return value > 0
    var xs: List[Int] = [0, 1, 2, 3]
    var caught = False
    try:
        _ = filter_forward_raised(checked, xs^)
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        assert_equal(error.at, 2)
        caught = True
    assert_equal(caught, True)
    assert_equal(calls, 3)
    def stop(value: Int) raises StopIteration -> Bool:
        raise StopIteration()
    caught = False
    try:
        _ = pipeline(Optional(1)).raising[StopIteration]().filter(stop).get()
    except error:
        comptime assert type_of(error) == StopIteration
        caught = True
    assert_equal(caught, True)
    caught = False
    try:
        _ = pipeline(Optional(7)).filter(ContainerFilterRaisingPredicate()).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        assert_equal(error.at, 7)
        caught = True
    assert_equal(caught, True)
    def deferred_failure(value: Int) raises ContainerFilterFailure -> Bool:
        raise ContainerFilterFailure(value)
    var deferred = filter[ContainerDeferredFamily](List[Int]([8]), deferred_failure)
    caught = False
    try:
        _ = deferred^.run()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        assert_equal(error.at, 8)
        caught = True
    assert_equal(caught, True)
    var drops = ArcPointer(0)
    def fail(value: ContainerMapItem) raises ContainerFilterFailure -> Bool:
        if value.value == 2: raise ContainerFilterFailure(2)
        return value.value > 0
    var items: List[ContainerMapItem] = [ContainerMapItem(0, drops), ContainerMapItem(1, drops), ContainerMapItem(2, drops), ContainerMapItem(3, drops)]
    try:
        _ = pipeline(items^).raising[ContainerFilterFailure]().filter(fail).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
        assert_equal(error.at, 2)
    assert_equal(drops[], 4)
    drops[] = 0
    var deque = Deque[ContainerMapItem]()
    deque.append(ContainerMapItem(1, drops))
    deque.append(ContainerMapItem(2, drops))
    deque.append(ContainerMapItem(3, drops))
    try:
        _ = pipeline(deque^).elements().raising[ContainerFilterFailure]().filter(fail).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
    assert_equal(drops[], 3)
    drops[] = 0
    var linked = LinkedList[ContainerMapItem]()
    linked.append(ContainerMapItem(1, drops))
    linked.append(ContainerMapItem(2, drops))
    try:
        _ = pipeline(linked^).elements().raising[ContainerFilterFailure]().filter(fail).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
    assert_equal(drops[], 2)
    drops[] = 0
    var keys = ArcPointer(0)
    var dict = Dict[ContainerMapKey, ContainerMapItem]()
    dict[ContainerMapKey(1, keys)] = ContainerMapItem(1, drops)
    dict[ContainerMapKey(2, keys)] = ContainerMapItem(2, drops)
    dict[ContainerMapKey(3, keys)] = ContainerMapItem(3, drops)
    try:
        _ = pipeline_values(dict^).raising[ContainerFilterFailure]().filter(fail).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
    assert_equal(drops[], 3)
    assert_equal(keys[], 3)
    drops[] = 0
    var kw = StringDict[ContainerMapItem]()
    kw["a"] = ContainerMapItem(1, drops)
    kw["b"] = ContainerMapItem(2, drops)
    try:
        _ = pipeline_values(kw^).raising[ContainerFilterFailure]().filter(fail).get()
    except error:
        comptime assert type_of(error) == ContainerFilterFailure
    assert_equal(drops[], 2)


def filter_origins(anchor: List[Int]) raises:
    var views: List[Span[Int, origin_of(anchor)]] = [Span(anchor)]
    def has_items(value: Span[Int, origin_of(anchor)]) {anchor} -> Bool:
        return len(value) > 0
    var kept = pipeline(views^).filter(has_items).get()
    assert_equal(kept[0][0], 11)


def main() raises:
    filter_shapes()
    filter_library_and_deferred()
    filter_moves()
    filter_errors()
    filter_origins([11, 12])
    print("container filter: eager calls, shape, moves, origins, errors, custom family")
