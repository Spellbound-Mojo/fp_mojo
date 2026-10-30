"""Combinator stages preserve native iterator, callback and ownership contracts."""
from fp.functions import Piped, piped
from fp.combinators import map, filter, fold_left
from fp.iteration import iterated, collect_list
from fp.callables import as_unary, Binary, BorrowCallable
from std.iter import Iterator, IterableOwned, iter, next
from std.memory import ArcPointer
from std.testing import assert_equal

def combinator_positive(value: Int) -> Bool: return value > 0
def combinator_square(value: Int) -> Int: return value * value
def combinator_add(total: Int, value: Int) -> Int: return total + value
def combinator_subtract(total: Int, value: Int) -> Int: return total - value
def combinator_report(total: Int) -> String: return "sum of positive squares = " + String(total)
def combinator_text(value: Int) -> String: return String(value)

@fieldwise_init
struct CombinatorFailure(Movable):
    var at: Int

@fieldwise_init
struct CombinatorItem(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def combinator_bump(var value: CombinatorItem) -> CombinatorItem:
    value.value += 1
    return value^

def combinator_keep(value: CombinatorItem) -> Bool: return value.value > 0

def combinator_accumulate(var total: CombinatorItem, var value: CombinatorItem) -> CombinatorItem:
    total.value += value.value
    return total^

@fieldwise_init
struct CombinatorRestarting(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var position: Int
    def __iter__(var self) -> Self:
        self.position = 0
        return self^
    def __next__(mut self) raises StopIteration -> Int:
        if self.position == 4: raise StopIteration()
        var value = self.position
        self.position += 1
        return value

@fieldwise_init
struct CombinatorAdd(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Never
    def call(self, var first: Int, var second: Int) -> Int:
        return first + second

@fieldwise_init
struct CombinatorPositive(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = Never
    def invoke(self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        return payload > 0

def combinator_examples() raises:
    var named = Piped[Value=Int](4)
    comptime assert type_of(named).Value == Int
    assert_equal(named^.get(), 4)
    assert_equal(piped[T=Int](5).get(), 5)
    var a: List[Int] = [3, -1, 4, -1, 5]
    var b = a.copy()
    var c = a.copy()
    var eager = piped(a^).filter(combinator_positive).map(combinator_square).fold_left(combinator_add, 0).then(combinator_report).get()
    var selected = filter(b^, combinator_positive)
    var squared = map(selected^, combinator_square)
    var direct = fold_left(squared^, 0, combinator_add)
    var lazy = iterated(c^).filter(combinator_positive).map(combinator_square).fold_left(combinator_add, 0)
    assert_equal(eager, "sum of positive squares = 50")
    assert_equal(combinator_report(direct), eager)
    assert_equal(combinator_report(lazy), eager)
    assert_equal(piped(List[Int]([0, 1, 2])).map(combinator_text).get(), ["0", "1", "2"])
    assert_equal(piped(range(0)).fold_left(combinator_add, 7).get(), 7)
    assert_equal(piped(range(1, 4)).fold_left(combinator_subtract, 10).get(), 4)

def combinator_captures_and_laziness() raises:
    var calls = ArcPointer(0)
    def combinator_counted(value: Int) {calls} -> Int:
        calls[] += 1
        return value * 2
    var lazy = iterated(range(4)).map(combinator_counted)
    assert_equal(calls[], 0)
    assert_equal(next(lazy), 0)
    assert_equal(calls[], 1)
    _ = lazy^
    assert_equal(calls[], 1)
    var bias = 0
    def combinator_changing(value: Int) {mut bias} -> Int:
        bias += 1
        return value + bias
    assert_equal(piped(List[Int]([0, 1, 2])).map(combinator_changing).get(), [1, 3, 5])
    assert_equal(bias, 3)
    calls[] = 0
    var folded = piped(List[Int]([0, 1, 2])).map(combinator_counted).fold_left(combinator_add, 0)
    assert_equal(calls[], 3)  # The fold ran before get.
    assert_equal(folded^.get(), 6)
    assert_equal(calls[], 3)
    var limit = 1
    def combinator_select(value: Int) {limit} -> Bool: return value > limit
    assert_equal(piped(List[Int]([0, 1, 2, 3])).filter(combinator_select).get(), [2, 3])
    def combinator_shifted(var total: Int, var value: Int) {limit} -> Int:
        return total + value + limit
    assert_equal(piped(range(3)).fold_left(combinator_shifted, 0).get(), 6)
    assert_equal(piped(List[Int]([0, 1, 2, 3])).filter(CombinatorPositive()).map(as_unary(combinator_square)).fold_left(CombinatorAdd(), 0).get(), 14)
    assert_equal(iterated(range(4)).filter(CombinatorPositive()).map(as_unary(combinator_square)).fold_left(CombinatorAdd(), 0), 14)

def combinator_ownership() raises:
    var drops = ArcPointer(0)
    var values: List[CombinatorItem] = [CombinatorItem(1, drops), CombinatorItem(-1, drops), CombinatorItem(3, drops)]
    var total = piped(values^).filter(combinator_keep).map(combinator_bump).fold_left(combinator_accumulate, CombinatorItem(0, drops)).get()
    assert_equal(total.value, 6)
    assert_equal(drops[], 3)
    _ = total^
    assert_equal(drops[], 4)
    var more: List[CombinatorItem] = [CombinatorItem(1, drops), CombinatorItem(2, drops)]
    var lazy = iterated(more^).map(combinator_bump)
    var first = next(lazy)
    assert_equal(first.value, 2)
    _ = first^
    _ = lazy^
    assert_equal(drops[], 6)
    var state = CombinatorItem(10, drops)
    def combinator_owned_capture(var value: Int) {var state^} -> Int:
        return value + state.value
    var captured = iterated(range(2)).map(combinator_owned_capture^)
    assert_equal(drops[], 6)
    assert_equal(collect_list(captured^), [10, 11])
    assert_equal(drops[], 7)

def combinator_origins_and_position(values: List[Int]) raises:
    var mapped = iterated(iter(values)).map(combinator_square)
    assert_equal(collect_list(mapped^), [9, 16])
    def combinator_view(var value: Int) {values} -> Span[Int, origin_of(values)]:
        return Span(values)
    var views = iterated(range(2)).map(combinator_view)
    var first = next(views)
    assert_equal(first[0], 3)
    _ = views^
    assert_equal(first[1], 4)
    var restarting = CombinatorRestarting(0)
    assert_equal(next(restarting), 0)
    assert_equal(collect_list(iterated(restarting^).map(combinator_square)), [1, 4, 9])

def combinator_errors() raises:
    var seen = ArcPointer(0)
    def combinator_check(total: Int, value: Int) raises CombinatorFailure {seen} -> Int:
        seen[] += 1
        if value == 2: raise CombinatorFailure(value)
        return total + value
    var caught = False
    try:
        _ = piped(range(5)).fold_left(combinator_check, 0).get()
    except error:
        comptime assert type_of(error) == CombinatorFailure
        assert_equal(error.at, 2)
        caught = True
    assert_equal(caught, True)
    assert_equal(seen[], 3)
    seen[] = 0
    caught = False
    try:
        _ = iterated(range(5)).fold_left(combinator_check, 0)
    except error:
        comptime assert type_of(error) == CombinatorFailure
        assert_equal(error.at, 2)
        caught = True
    assert_equal(caught, True)
    assert_equal(seen[], 3)

def main() raises:
    combinator_examples()
    combinator_captures_and_laziness()
    combinator_ownership()
    combinator_origins_and_position([3, 4])
    combinator_errors()
    print("combinators: examples, laziness, captures, moves, origins, exact errors")
