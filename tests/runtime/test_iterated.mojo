"""Chained adapters and terminals preserve order, laziness and empty behavior."""
from fp.iteration import iterated, EmptyReductionError
from fp.data import ControlFlow, Break, Continue
from fp.callables import as_unary, Binary, BorrowCallable
from std.collections.string import Codepoint
from std.iter import enumerate, next
from std.testing import assert_equal


def twice(var value: Int) -> Int:
    return value * 2

def positive(value: Int) -> Bool:
    return value > 0

def even(var value: Int) -> Optional[Int]:
    return Optional(value) if value % 2 == 0 else None

def add(var total: Int, var value: Int) -> Int:
    return total + value

def subtract(var total: Int, var value: Int) -> Int:
    return total - value

def stop(var total: Int, var value: Int) -> ControlFlow[Int, Int]:
    if value == 3:
        return Break(total)
    return Continue(total + value)

@fieldwise_init
struct IteratedAdd(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Never
    def call(self, var first: Int, var second: Int) -> Int:
        return first + second

@fieldwise_init
struct IteratedStop(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = ControlFlow[Int, Int]
    comptime Error = Never
    def call(self, var first: Int, var second: Int) -> Self.Out:
        return stop(first, second)

@fieldwise_init
struct IteratedPositive(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = Never
    def invoke(self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        return payload > 0

def codepoints_of(s: String) -> List[Codepoint]:
    return List(s.codepoints())


def main() raises:
    var words: List[String] = ["hello", "world"]
    var chars = iterated(words^).flat_map(codepoints_of).to_list()
    assert_equal(chars, List("helloworld".codepoints()))
    var numbered = enumerate(iterated(range(3)), start=4)
    var pairs = iterated(numbered^).collect_list()
    assert_equal(pairs, [(4, 0), (5, 1), (6, 2)])
    var source = iterated(range(3))
    assert_equal(next(source), 0)
    assert_equal(source^.to_list(), [1, 2])
    var offset = 10
    def expand(var value: Int) {var offset} -> List[Int]:
        return [value, value + offset]
    assert_equal(iterated(range(2)).flat_map(expand).collect_list(), [0, 10, 1, 11])
    assert_equal(iterated(range(-2, 4)).filter(positive).map(twice).filter_map(even).scan_left(add, 0).to_list(), [0, 2, 6, 12])
    var nested: List[List[Int]] = [[], [1, 2], [], [3], []]
    assert_equal(iterated(nested^).flatten().to_list(), [1, 2, 3])
    assert_equal(iterated(range(1, 4)).fold_left(subtract, 10), 4)
    assert_equal(iterated(range(1, 4)).reduce(add), 6)
    assert_equal(iterated(range(1, 4)).reduce(subtract, initial=10), 4)
    assert_equal(iterated(range(1, 4)).reduce_optional(add).value(), 6)
    assert_equal(Bool(iterated(range(0)).reduce_optional(add)), False)
    assert_equal(iterated(range(0)).fold_left(add, 10), 10)
    assert_equal(iterated(range(0)).reduce(add, initial=10), 10)
    assert_equal(iterated(range(0)).to_list(), List[Int]())
    assert_equal(iterated(range(0)).collect_list(), List[Int]())
    var empty_failed = False
    try:
        _ = iterated(range(0)).reduce(add)
    except error:
        comptime assert type_of(error) == EmptyReductionError
        empty_failed = True
    assert_equal(empty_failed, True)
    assert_equal(Bool(iterated(range(0)).find(positive)), False)
    assert_equal(iterated(range(-2, 4)).find(positive).value(), 1)
    assert_equal(iterated(range(0)).any(positive), False)
    assert_equal(iterated(range(0)).all(positive), True)
    assert_equal(iterated(range(-2, 4)).any(positive), True)
    assert_equal(iterated(range(-2, 4)).all(positive), False)
    var broken = iterated(range(1, 8)).fold_until(stop, 0)
    assert_equal(broken.isa[Break[Int]](), True)
    assert_equal(broken[Break[Int]].value, 3)
    var continued = iterated(range(0)).fold_until(stop, 7)
    assert_equal(continued[Continue[Int]].value, 7)

    # Stored captures are evaluated only as the terminal pulls the chain.
    var calls = 0
    def counted(var value: Int) {mut calls} -> Int:
        calls += 1
        return value * 2
    def selected(value: Int) {var offset} -> Bool:
        return value < offset
    def present(var value: Int) {var offset} -> Optional[Int]:
        return Optional(value + offset)
    def sum_step(var total: Int, var value: Int) {var offset} -> Int:
        return total + value + offset
    var lazy = iterated(range(3)).map(counted).filter(selected).filter_map(present).scan_left(sum_step, 0)
    assert_equal(calls, 0)
    assert_equal(next(lazy), 0)
    assert_equal(calls, 0)
    assert_equal(next(lazy), 20)
    assert_equal(calls, 1)
    _ = lazy^
    assert_equal(calls, 1)

    # Library callables retain the same admission rules as the free functions.
    assert_equal(iterated(range(3)).map(as_unary(twice)).to_list(), [0, 2, 4])
    assert_equal(iterated(range(4)).filter_map[U=Int](as_unary(even)).to_list(), [0, 2])
    var texts: List[String] = ["é", "", "水"]
    assert_equal(iterated(texts^).flat_map(as_unary(codepoints_of)).to_list(), List("é水".codepoints()))
    assert_equal(iterated(range(3)).filter(IteratedPositive()).to_list(), [1, 2])
    assert_equal(iterated(range(3)).scan_left(IteratedAdd(), 0).to_list(), [0, 0, 1, 3])
    assert_equal(iterated(range(3)).fold_left(IteratedAdd(), 1), 4)
    assert_equal(iterated(range(3)).reduce(IteratedAdd()), 3)
    assert_equal(iterated(range(3)).reduce(IteratedAdd(), initial=1), 4)
    assert_equal(iterated(range(3)).reduce_optional(IteratedAdd()).value(), 3)
    assert_equal(iterated(range(1, 5)).fold_until(IteratedStop(), 0)[Break[Int]].value, 3)
    assert_equal(iterated(range(3)).find(IteratedPositive()).value(), 1)
    assert_equal(iterated(range(3)).any(IteratedPositive()), True)
    assert_equal(iterated(range(3)).all(IteratedPositive()), False)
