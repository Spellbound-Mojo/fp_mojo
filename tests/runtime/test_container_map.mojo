"""Piped.map preserves native shape, evaluation, ownership and exact errors."""
from std.collections import Array, Deque, LinkedList, StringDict
from std.hash import default_comp_time_hasher, Hasher
from std.memory import ArcPointer
from std.testing import assert_equal
from fp.functions import piped, Piped
from fp.iteration import iterated, collect_list
from fp.callables import as_unary, MutableUnary, OnceUnary
from fp.algebra import ListFamily, OptionalFamily
from fp.data import Result, Ok, Err
from test_algebra_third_party import Cell, CellFamily


def container_text(value: Int) -> String: return String(value)
def container_square(value: Int) -> Int: return value * value

@fieldwise_init
struct ContainerMapFailure(Movable):
    var at: Int

@fieldwise_init
struct ContainerMapItem(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct ContainerMapCounter(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var arg: Int) -> Int:
        self.calls += 1
        return arg + self.calls

@fieldwise_init
struct ContainerMapOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int:
        return arg + 1


@fieldwise_init
struct ContainerMapKey(Movable, Hashable, Equatable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1
    def __hash__[H: Hasher](self, mut hasher: H):
        self.value.__hash__(hasher)
    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value


def container_checked(var value: ContainerMapItem) raises ContainerMapFailure -> ContainerMapItem:
    if value.value == 2:
        raise ContainerMapFailure(value.value)
    return ContainerMapItem(value.value * 2, value.drops)


def container_generic[T: Movable & Deinitable, U: Movable & Deinitable, //,
                      F: def(var T) -> U](ref function: F, var values: List[T]) -> Piped[List[U]]:
    return piped(values^).map[ListFamily](function)


def container_generic_raised[T: Movable & Deinitable, U: Movable & Deinitable,
                            E: Movable & Deinitable, //, F: def(var T) raises E -> U](
    ref function: F, var values: List[T]
) raises E -> List[U]:
    return piped(values^).map[ListFamily, E=E](function).get()


def container_shapes() raises:
    var calls = 0
    def counted(value: Int) {mut calls} -> String:
        calls += 1
        return String(value)
    var values: List[Int] = [3, 1, 2]
    var stage = piped(values^).map(counted)
    comptime assert type_of(stage) == Piped[List[String]]
    assert_equal(calls, 3)  # Mapping completed before get.
    assert_equal(stage^.get(), ["3", "1", "2"])
    var empty = List[Int]()
    assert_equal(len(piped(empty^).map(counted).get()), 0)
    assert_equal(calls, 3)
    var xs: List[Int] = [2, 3]
    assert_equal(container_generic(container_square, xs^).map(container_text).get(), ["4", "9"])
    var ys: List[Int] = [0, 0, 0]
    assert_equal(piped(ys^).map(ContainerMapCounter(0)).get(), [1, 2, 3])
    var a: Array[Int, 3] = [3, 1, 2]
    var b = piped(a^).map(container_text).get()
    comptime assert type_of(b) == Array[String, 3]
    assert_equal(collect_list(b^), ["3", "1", "2"])
    var zero = Array[Int, 0](fill=0)
    var no_items = piped(zero^).map(counted).get()
    comptime assert type_of(no_items) == Array[String, 0]
    assert_equal(len(no_items), 0)
    assert_equal(calls, 3)
    var deque = Deque[Int](capacity=8, min_capacity=4, maxlen=3, shrink=False)
    deque.append(4)
    deque.append(1)
    deque.append(2)
    var mapped_deque = piped(deque^).map(as_unary(container_text)).get()
    comptime assert type_of(mapped_deque) == Deque[String]
    assert_equal(mapped_deque._min_capacity, 4)
    assert_equal(mapped_deque._shrink, False)
    mapped_deque.append("new")  # The original bound still evicts from the left.
    assert_equal(collect_list(mapped_deque^), ["1", "2", "new"])
    var linked = LinkedList[Int]()
    linked.append(3)
    linked.append(1)
    var mapped_linked = piped(linked^).map(container_text).get()
    comptime assert type_of(mapped_linked) == LinkedList[String]
    assert_equal(collect_list(mapped_linked^), ["3", "1"])
    var dict = Dict[String, Int, default_comp_time_hasher]()
    dict["b"] = 2
    dict["a"] = 1
    dict["b"] = 3
    var mapped_dict = piped(dict^).map(container_text).get()
    comptime assert type_of(mapped_dict) == Dict[String, String, default_comp_time_hasher]
    assert_equal(mapped_dict["b"], "3")
    assert_equal(collect_list(mapped_dict^), ["b", "a"])
    var kw = StringDict[Int]()
    kw["x"] = 4
    var mapped_kw = piped(kw^).map(container_text).get()
    comptime assert type_of(mapped_kw) == StringDict[String]
    assert_equal(mapped_kw["x"], "4")
    var once = piped(Optional(2)).map(ContainerMapOnce()).get()
    assert_equal(once.take(), 3)
    assert_equal(Bool(piped(Optional[Int]()).map(counted).get()), False)
    assert_equal(calls, 3)
    var success = Result[Int, String](Ok(4))
    var mapped_success = piped(success^).map(container_text).get()
    comptime assert type_of(mapped_success) == Result[String, String]
    assert_equal(mapped_success^._take_ok(), "4")
    var failure = Result[Int, String](Err(String("absent")))
    var mapped_failure = piped(failure^).map(counted).get()
    assert_equal(mapped_failure^._take_err(), "absent")
    assert_equal(calls, 3)
    var custom = piped(Cell(5)).map[CellFamily](container_text).get()
    assert_equal(custom^.take(), "5")
    var explicit: List[Int] = [2, 3]
    assert_equal(piped(explicit^).map[ListFamily](container_square).get(), [4, 9])


def container_origins(anchor: List[Int]) raises:
    def view(value: Int) {anchor} -> Span[Int, origin_of(anchor)]:
        return Span(anchor)
    var xs: List[Int] = [1, 2]
    var views = container_generic(view, xs^).get()
    assert_equal(views[0][0], 11)
    assert_equal(views[1][1], 12)
    var a: Array[Int, 2] = [1, 2]
    var array_views = piped(a^).map(view).get()
    assert_equal(array_views[1][0], 11)


def container_cleanup() raises:
    var drops = ArcPointer(0)
    var caught = False
    var xs: List[ContainerMapItem] = [ContainerMapItem(0, drops), ContainerMapItem(1, drops), ContainerMapItem(2, drops), ContainerMapItem(3, drops)]
    try:
        _ = container_generic_raised(container_checked, xs^)
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        assert_equal(error.at, 2)
        caught = True
    assert_equal(caught, True)
    assert_equal(drops[], 6)  # Four inputs and two constructed outputs.
    drops[] = 0
    caught = False
    var array: Array[ContainerMapItem, 4] = [ContainerMapItem(0, drops), ContainerMapItem(1, drops), ContainerMapItem(2, drops), ContainerMapItem(3, drops)]
    try:
        _ = piped(array^).map(container_checked).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        caught = True
    assert_equal(caught, True)
    assert_equal(drops[], 6)
    drops[] = 0
    caught = False
    var dict = Dict[String, ContainerMapItem]()
    dict["a"] = ContainerMapItem(0, drops)
    dict["b"] = ContainerMapItem(1, drops)
    dict["c"] = ContainerMapItem(2, drops)
    dict["d"] = ContainerMapItem(3, drops)
    try:
        _ = piped(dict^).map(container_checked).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        caught = True
    assert_equal(caught, True)
    assert_equal(drops[], 6)
    def stop(value: Int) raises StopIteration -> Int:
        raise StopIteration()
    caught = False
    try:
        _ = piped(Optional(1)).map(stop).get()
    except error:
        comptime assert type_of(error) == StopIteration
        caught = True
    assert_equal(caught, True)
    def checked_cell(value: Int) raises ContainerMapFailure -> Int:
        raise ContainerMapFailure(value)
    caught = False
    try:
        _ = piped(Cell(7)).map[CellFamily](checked_cell).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        assert_equal(error.at, 7)
        caught = True
    assert_equal(caught, True)


def container_more_cleanup() raises:
    var drops = ArcPointer(0)
    var keys = ArcPointer(0)
    var dict = Dict[ContainerMapKey, ContainerMapItem]()
    dict[ContainerMapKey(7, keys)] = ContainerMapItem(1, drops)
    dict[ContainerMapKey(8, keys)] = ContainerMapItem(2, drops)
    var caught = False
    try:
        _ = piped(dict^).map(container_checked).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        caught = True
    assert_equal(caught, True)
    assert_equal(keys[], 2)
    assert_equal(drops[], 3)
    drops[] = 0
    var deque = Deque[ContainerMapItem]()
    deque.append(ContainerMapItem(1, drops))
    deque.append(ContainerMapItem(2, drops))
    caught = False
    try:
        _ = piped(deque^).map(container_checked).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        caught = True
    assert_equal(caught, True)
    assert_equal(drops[], 3)
    drops[] = 0
    var linked = LinkedList[ContainerMapItem]()
    linked.append(ContainerMapItem(1, drops))
    linked.append(ContainerMapItem(2, drops))
    caught = False
    try:
        _ = piped(linked^).map(as_unary(container_checked)).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        caught = True
    assert_equal(caught, True)
    assert_equal(drops[], 3)
    drops[] = 0
    var kw = StringDict[ContainerMapItem]()
    kw["a"] = ContainerMapItem(1, drops)
    kw["b"] = ContainerMapItem(2, drops)
    caught = False
    try:
        _ = piped(kw^).map(container_checked).get()
    except error:
        comptime assert type_of(error) == ContainerMapFailure
        caught = True
    assert_equal(caught, True)
    assert_equal(drops[], 3)
    drops[] = 0
    var a = Array[ContainerMapItem, 2](fill_with=lambda (i: Int) {drops} -> ContainerMapItem: ContainerMapItem(i, drops))
    def keep(var x: ContainerMapItem) -> ContainerMapItem:
        return ContainerMapItem(x.value * 2, x.drops)
    var b = piped(a^).map(keep).get()
    assert_equal(drops[], 2)
    assert_equal(b[1].value, 2)
    _ = b^
    assert_equal(drops[], 4)


def main() raises:
    container_shapes()
    container_origins([11, 12])
    container_cleanup()
    container_more_cleanup()
    print("container map: shape, eager calls, origins, moves, exact errors, external families")
