# error: origin_of(local)
"""Same-source origin assignment and captured flat mapping of borrowed inner lists."""
from fp.iteration import FilterIterator, FilterMapIterator, FlatMapIterator, filter, filter_map, flat_map, collect_list
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

def source_origins(anchor: List[Int]) raises:
    var local: List[Int] = [1, 2]
    var offset = 2
    def predicate(value: Int) {var offset} -> Bool: return value < offset + 1
    def optional(var value: Int) {var offset} -> Optional[Int]: return Optional(value + offset)
    def expand(var value: Int) {var offset} -> List[Int]: return [value, value + offset]
    var expected_filter = selected_again(predicate, borrowed(anchor))
    var candidate_filter = selected_again(predicate, borrowed(anchor))
    var selected: type_of(expected_filter) = candidate_filter^
    assert_equal(collect_list(selected^), [1, 2])
    var expected_optional = present_again(optional, borrowed(anchor))
    var candidate_optional = present_again(optional, borrowed(local))
    var mapped: type_of(expected_optional) = candidate_optional^
    assert_equal(collect_list(mapped^), [3, 4])
    var expected_flat = expanded_again(expand, borrowed(anchor))
    var candidate_flat = expanded_again(expand, borrowed(anchor))
    var flattened: type_of(expected_flat) = candidate_flat^
    assert_equal(collect_list(flattened^), [1, 3, 2, 4])
    _ = expected_filter^
    _ = expected_optional^
    _ = expected_flat^

def borrowed_inners(values: List[Int]) raises:
    var calls = 0
    def expand(var value: Int) {values, mut calls} -> List[Int].IteratorType[origin_of(values)]:
        calls += value
        return iter(values)
    var flattened = expanded_again(expand, iter(range(3)))
    assert_equal(calls, 0)
    assert_equal(collect_list(flattened^), [1, 2, 1, 2, 1, 2])
    assert_equal(calls, 3)

def main() raises:
    var values: List[Int] = [1, 2]
    source_origins(values)
    borrowed_inners(values)
    assert_equal(values, [1, 2])
