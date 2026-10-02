"""Generic filtering helpers preserve lazy state and borrowed sources."""
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

def main() raises:
    var predicates = 0
    var optionals = 0
    var expansions = 0
    def positive(value: Int) {mut predicates} -> Bool:
        predicates += 1
        return value > 0
    def even_label(var value: Int) {mut optionals} -> Optional[String]:
        optionals += 1
        if value % 2: return None
        return Optional(String(value))
    def pair(var value: String) {mut expansions} -> List[String]:
        expansions += 1
        return [value.copy(), value + "!"]
    var values: List[Int] = [0, 1, 2, 3, 4, 5]
    var output = expanded_again(pair, present_again(even_label, selected_again(positive, iter(values))))
    assert_equal(predicates, 0)
    assert_equal(optionals, 0)
    assert_equal(expansions, 0)
    assert_equal(next(output), "2")
    assert_equal(next(output), "2!")
    assert_equal(predicates, 3)
    assert_equal(optionals, 2)
    assert_equal(expansions, 1)
    assert_equal(next(output), "4")
    assert_equal(predicates, 5)
    assert_equal(optionals, 4)
    assert_equal(expansions, 2)
    assert_equal(values, [0, 1, 2, 3, 4, 5])
    print("generic filtering: 2, 2!, 4; tail unevaluated")
