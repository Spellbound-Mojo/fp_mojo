"""Generic return aliases retain nominal types, thin defaults and separate progress."""
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

def thin_selected[T: Movable & Deinitable, I: Iterator](
    function: def(T) thin -> Bool, var source: I
) -> FilterIterator[T, I] where I.Element == T:
    return filter(function, source^)

def thin_present[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator](
    function: def(var T) thin -> Optional[U], var source: I
) -> FilterMapIterator[T, U, I] where I.Element == T:
    return filter_map(function, source^)

def thin_expanded[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator](
    function: def(var T) thin -> U, var source: I
) -> FlatMapIterator[T, U, I] where I.Element == T:
    return flat_map(function, source^)

@fieldwise_init
struct First(Copyable):
    var value: Int

@fieldwise_init
struct Second(Copyable):
    var value: Int

def accept(value: First) -> Bool: return value.value > 0
def optional(var value: First) -> Optional[Second]: return Optional(Second(value.value + 10))
def expand(var value: Second) -> List[Int]: return [value.value, value.value + 1]

def main() raises:
    comptime assert First != Second
    var items = List[First]()
    items.append(First(1))
    items.append(First(2))
    var first = thin_selected(accept, iter(items))
    var second = thin_present(optional, first^)
    var output = thin_expanded(expand, second^)
    assert_equal(collect_list(output^), [11, 12, 12, 13])
    var captured = 0
    def predicate(value: First) {mut captured} -> Bool:
        captured += 1
        return value.value > 0
    var selected = selected_again(predicate, iter(items))
    assert_equal(next(selected).value, 1)
    assert_equal(captured, 1)
    var a_calls = 0
    var b_calls = 0
    def label(var value: Int) {mut a_calls} -> Optional[String]:
        a_calls += 1
        return Optional(String(value + 10 * a_calls))
    def pair(var value: Int) {mut b_calls} -> List[Int]:
        b_calls += 1
        return [value, value + 10 * b_calls]
    var values: List[Int] = [1, 2, 3]
    var a = present_again(label, iter(values))
    var b = expanded_again(pair, iter(values))
    assert_equal(next(a), "11")
    assert_equal(next(b), 1)
    assert_equal(next(a), "22")
    assert_equal(next(b), 11)
    assert_equal(b_calls, 1)
    assert_equal(next(b), 2)
    assert_equal(next(a), "33")
    assert_equal(a_calls, 3)
    assert_equal(b_calls, 2)
    assert_equal(values, [1, 2, 3])
