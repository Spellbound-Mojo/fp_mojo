"""Lazy event order, exhaustion, Optional/Result separation and native interop."""
from fp.iteration import map, filter, filter_map, flat_map, flatten, collect_list
from fp.data import Result, Ok, Err, collect_results
from std.iter import Iterator, iter, once, empty, chain, zip, enumerate, peekable
from std.itertools import take, drop, take_while, drop_while
from std.memory import ArcPointer
from observations import Trace, count, record
from std.testing import assert_equal
from std.builtin.rebind import downcast, rebind_var

@fieldwise_init
struct Item(Movable):
    var value: Int
    var trace: Trace

@fieldwise_init
struct Source(Iterator):
    comptime Element = Item
    var index: Int
    var count: Int
    var trace: Trace
    def __next__(mut self) raises StopIteration -> Item:
        record(self.trace, self.index)
        if self.index == self.count: raise StopIteration()
        self.index += 1
        return Item(self.index, self.trace)

def doubled(var item: Item) -> Int:
    record(item.trace, 100 + item.value)
    return 2 * item.value

def even(item: Item) -> Bool:
    record(item.trace, 100 + item.value)
    return item.value % 2 == 0

def selected(var item: Item) -> Optional[Int]:
    return Optional(item.value) if even(item) else None

def unpack(var item: Item) -> List[Int]:
    record(item.trace, 100 + item.value)
    if item.value == 2: return List[Int]()
    return [item.value, -item.value]

def check[It: Iterator](mut iterator: It) raises:
    for _ in range(2):
        var stopped = False
        try: _ = rebind_var[downcast[It.Element, Movable & Deinitable]](iterator.__next__())
        except: stopped = True
        assert_equal(stopped, True)

def positive(value: Int) -> Bool:
    return value > 0

def result_value(var value: Int) -> Result[Int, Int]:
    if value == 2: return Result[Int, Int](Err(72))
    return Result[Int, Int](Ok(value))

def optional_result(var value: Int) -> Optional[Result[Int, Int]]:
    if value == 0: return None
    return Optional(result_value(value))

def borrowed(values: List[Int]) -> List[Int].IteratorType[origin_of(values)]:
    return values.__iter__()


def borrow_flat(values: List[Int]) -> type_of(flatten(once(borrowed(values)))):
    return flatten(once(borrowed(values)))


def main() raises:
    var trace = ArcPointer(List[Int]())
    var mapped = map(doubled, Source(0, 2, trace))
    assert_equal(len(trace[]), 0)
    assert_equal(mapped.__next__(), 2)
    var expected: List[Int] = [0, 101]
    assert_equal(trace[], expected)
    assert_equal(mapped.__next__(), 4)
    check(mapped)
    expected = [0, 101, 1, 102, 2]
    assert_equal(trace[], expected)

    trace[].clear()
    var filtered = filter(even, Source(0, 3, trace))
    assert_equal(len(trace[]), 0)
    var retained = filtered.__next__()
    assert_equal(retained.value, 2)
    expected = [0, 101, 1, 102]
    assert_equal(trace[], expected)
    check(filtered)
    expected = [0, 101, 1, 102, 2, 103, 3]
    assert_equal(trace[], expected)

    trace[].clear()
    var optional = filter_map(selected, Source(0, 3, trace))
    assert_equal(len(trace[]), 0)
    assert_equal(optional.__next__(), 2)
    check(optional)
    assert_equal(trace[], expected)

    trace[].clear()
    var flat = flat_map(unpack, Source(0, 3, trace))
    assert_equal(len(trace[]), 0)
    assert_equal(flat.__next__(), 1)
    assert_equal(flat.__next__(), -1)
    expected = [0, 101]
    assert_equal(trace[], expected)
    assert_equal(flat.__next__(), 3)
    expected = [0, 101, 1, 102, 2, 103]
    assert_equal(trace[], expected)
    assert_equal(flat.__next__(), -3)
    check(flat)
    expected.append(3)
    assert_equal(trace[], expected)

    var native_values: List[Int] = [1, 2, 3]
    var borrowed_inner = borrowed(native_values)
    assert_equal(collect_list(flatten(once(borrowed_inner^))), native_values)
    assert_equal(collect_list(borrow_flat(native_values)), native_values)
    var nested: List[List[Int]] = [[], [1, 2], [], [3], []]
    assert_equal(collect_list(flatten(iter(nested^))), native_values)
    var no_inners = List[List[Int]]()
    assert_equal(len(collect_list(flatten(iter(no_inners^)))), 0)
    var only_empty: List[List[Int]] = [[], []]
    assert_equal(len(collect_list(flatten(iter(only_empty^)))), 0)

    # Result is an ordinary element; only collect_results stops at Err.
    var results = collect_list(filter_map(optional_result, iter(range(4))))
    assert_equal(len(results), 3)
    assert_equal(results[1].is_err(), True)
    var error = collect_results(map(result_value, iter(range(4))))
    var caught = False
    try:
        _ = error^.raise_on_err()
    except failure:
        caught = True
        assert_equal(failure, 72)
    assert_equal(caught, True)

    # Canonical standard adapters consume our native Iterator/IterableOwned.
    trace[].clear()
    var limited = take(map(doubled, Source(0, 5, trace)), 1)
    expected = [2]
    assert_equal(collect_list(limited^), expected)
    expected = [0, 101]
    assert_equal(trace[], expected)
    trace[].clear()
    var zero = take(map(doubled, Source(0, 5, trace)), 0)
    assert_equal(len(collect_list(zero^)), 0)
    assert_equal(len(trace[]), 0)
    var combined = chain(once(1), once(2))
    expected = [1, 2]
    assert_equal(collect_list(combined^), expected)
    var pairs = zip(once(1), once(2))
    var pair = pairs.__next__()
    assert_equal(pair[0], 1)
    assert_equal(pair[1], 2)
    var indexed = enumerate(once(8), start=4)
    var index_value = indexed.__next__()
    assert_equal(index_value[0], 4)
    assert_equal(index_value[1], 8)
    assert_equal(len(collect_list(empty[Int]())), 0)
    var skipped = drop(iter([1, 2, 3]), 2)
    expected = [3]
    assert_equal(collect_list(skipped^), expected)
    var prefix = take_while[positive]([1, 2, 0, 3])
    expected = [1, 2]
    assert_equal(collect_list(prefix^), expected)
    var suffix = drop_while[positive]([1, 2, 0, 3])
    expected = [0, 3]
    assert_equal(collect_list(suffix^), expected)
    var peek = peekable(once(7))
    assert_equal(peek.peek().value()[], 7)
    assert_equal(peek.__next__(), 7)
