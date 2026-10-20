"""Native adapters, generic returns and source positions through method chains."""
from fp.iteration import Iter, MapIterator, FlatMapIterator, iterated, collect_list
from std.iter import Iterator, IterableOwned, iter, next, enumerate, zip, chain, once
from std.itertools import take
from std.testing import assert_equal


@fieldwise_init
struct IteratedRestarting(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var position: Int
    def __iter__(var self) -> Self:
        self.position = 0
        return self^
    def __next__(mut self) raises StopIteration -> Int:
        if self.position == 4:
            raise StopIteration()
        var result = self.position
        self.position += 1
        return result


def mapped[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
           F: def(var T) -> U](var function: F, var source: I
) -> Iter[MapIterator[T, U, I, F]] where I.Element == T:
    return iterated(source^).map(function^)

def expanded[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
             F: def(var T) -> U](var function: F, var source: I
) -> Iter[FlatMapIterator[T, U, I, F]] where I.Element == T:
    return iterated(source^).flat_map(function^)

def thin_mapped[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator](
    function: def(var T) thin -> U, var source: I
) -> Iter[MapIterator[T, U, I]] where I.Element == T:
    return iterated(source^).map(function)

def twice(var value: Int) -> Int:
    return value * 2

def borrowed(values: List[Int]) -> Iter[List[Int].IteratorType[origin_of(values)]]:
    return iterated(iter(values))

def main() raises:
    var restarted = IteratedRestarting(0)
    assert_equal(next(restarted), 0)
    var wrapped = iterated(restarted^)
    assert_equal(next(wrapped), 1)
    var indexed = enumerate(wrapped^, start=10)
    assert_equal(iterated(indexed^).to_list(), [(10, 2), (11, 3)])

    var source = iterated(range(5))
    assert_equal(next(source), 0)
    var bounds = source.bounds()
    assert_equal(bounds[0], 4)
    assert_equal(bounds[1].value(), 4)
    var resumed = iterated(iter(source^))
    assert_equal(resumed^.to_list(), [1, 2, 3, 4])
    var pairs = zip(iterated(range(3)), iterated(range(10, 12)))
    assert_equal(iterated(pairs^).collect_list(), [(0, 10), (1, 11)])
    var combined = chain(iterated(range(2)), iterated(range(2, 4)))
    assert_equal(collect_list(combined^), [0, 1, 2, 3])
    var limited = take(iterated(range(10)).map(twice), 2)
    assert_equal(iterated(limited^).to_list(), [0, 2])
    var loop = iterated(range(1, 4))
    var total = 0
    for value in loop^:
        total += value
    assert_equal(total, 6)

    var values: List[Int] = [4, 5, 6]
    var view = borrowed(values)
    assert_equal(view^.to_list(), [4, 5, 6])
    assert_equal(values, [4, 5, 6])
    var anchor: List[Int] = [11, 12]
    origins(values, anchor)


def origins(values: List[Int], anchor: List[Int]) raises:
    var expected = iterated(iter(anchor))
    var candidate = iterated(iter(anchor))
    var same: type_of(expected) = candidate^
    assert_equal(same^.to_list(), [11, 12])
    _ = expected^
    var expected_inner = iterated(once(iter(anchor))).flatten()
    var candidate_inner = iterated(once(iter(anchor))).flatten()
    var same_inner: type_of(expected_inner) = candidate_inner^
    assert_equal(same_inner^.to_list(), [11, 12])
    _ = expected_inner^
    var calls = 0
    def capture(var value: Int) {mut calls, anchor} -> Span[Int, origin_of(anchor)]:
        calls += value
        return Span(anchor)
    var views = mapped(capture, iter(values))
    assert_equal(calls, 0)
    var first = next(views)
    assert_equal(first[0], 11)
    assert_equal(calls, 4)
    _ = views^
    assert_equal(calls, 4)
    def inner(var value: Int) {anchor} -> List[Int].IteratorType[origin_of(anchor)]:
        return iter(anchor)
    var flattened = expanded(inner, iter(range(2)))
    assert_equal(flattened^.to_list(), [11, 12, 11, 12])
    assert_equal(thin_mapped(twice, iter(range(3))).to_list(), [0, 2, 4])
