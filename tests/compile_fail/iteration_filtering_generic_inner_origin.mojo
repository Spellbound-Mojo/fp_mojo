# error: origin_of(local)
"""Generic flat-map aliases retain the borrowed inner result origin."""
from fp.iteration import FilterIterator, FilterMapIterator, FlatMapIterator, filter, filter_map, flat_map
from std.iter import Iterator, IterableOwned, iter, next
from std.testing import assert_equal

def selected[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](
    var function: F, var source: I
) -> FilterIterator[T, I, F] where I.Element == T:
    return filter(function^, source^)

def selected_again[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](
    var function: F, var source: I
) -> FilterIterator[T, I, F] where I.Element == T:
    return selected(function^, source^)

def present[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> Optional[U]](
    var function: F, var source: I
) -> FilterMapIterator[T, U, I, F] where I.Element == T:
    return filter_map(function^, source^)

def present_again[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> Optional[U]](
    var function: F, var source: I
) -> FilterMapIterator[T, U, I, F] where I.Element == T:
    return present(function^, source^)

def expanded[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> U](
    var function: F, var source: I
) -> FlatMapIterator[T, U, I, F] where I.Element == T:
    return flat_map(function^, source^)

def expanded_again[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> U](
    var function: F, var source: I
) -> FlatMapIterator[T, U, I, F] where I.Element == T:
    return expanded(function^, source^)

def borrowed(values: List[Int]) -> List[Int].IteratorType[origin_of(values)]:
    return iter(values)

def inner_origins(anchor: List[Int]) raises:
    var local: List[Int] = [7, 8]
    var anchor_inner = borrowed(anchor)
    var local_inner = borrowed(local)
    var calls = 0
    def expand(var value: Int) {anchor, mut calls} -> List[Int].IteratorType[origin_of(anchor)]:
        calls += 1
        return iter(anchor)
    var outer: List[Int] = [1, 2]
    var source = iter(outer^)
    comptime Source = type_of(source)
    var original = expanded_again(expand, source^)
    var forwarded: FlatMapIterator[Int, type_of(local_inner), Source, type_of(expand)] = original^
    assert_equal(next(forwarded), 1)
    assert_equal(next(forwarded), 2)
    assert_equal(calls, 1)
    assert_equal(next(anchor_inner), 1)
    assert_equal(next(local_inner), 7)

def main() raises:
    var values: List[Int] = [1, 2]
    inner_origins(values)
