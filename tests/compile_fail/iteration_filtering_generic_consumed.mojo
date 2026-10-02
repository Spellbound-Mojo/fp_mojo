# error: use of uninitialized value 'predicate'
# error: use of uninitialized value 'optional'
# error: use of uninitialized value 'expand'
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

@fieldwise_init
struct State(Movable):
    var value: Int

def main():
    var first = State(2)
    def predicate(value: Int) {var first^} -> Bool: return value > first.value
    _ = selected_again(predicate^, iter(range(3)))
    _ = predicate(1)
    var second = State(2)
    def optional(var value: Int) {var second^} -> Optional[Int]: return Optional(value + second.value)
    _ = present_again(optional^, iter(range(3)))
    _ = optional(1)
    var third = State(2)
    def expand(var value: Int) {var third^} -> List[Int]: return [value, third.value]
    _ = expanded_again(expand^, iter(range(3)))
    _ = expand(1)
