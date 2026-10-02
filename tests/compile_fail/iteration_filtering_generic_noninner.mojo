# error: IterableOwned
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
struct NonIterable(Movable):
    var value: Int

def main():
    var offset = 1
    def noninner(var value: Int) {var offset} -> NonIterable: return NonIterable(value + offset)
    _ = expanded_again(noninner, iter(range(3)))
