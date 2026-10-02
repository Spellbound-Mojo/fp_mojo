# error: invalid call to 'selected_again'
# error: invalid call to 'present_again'
# error: invalid call to 'expanded_again'
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

def main():
    var offset = 1
    def predicate(value: Int) raises StopIteration {var offset} -> Bool:
        if value == offset: raise StopIteration()
        return True
    def optional(var value: Int) raises StopIteration {var offset} -> Optional[Int]:
        if value == offset: raise StopIteration()
        return Optional(value)
    def expand(var value: Int) raises StopIteration {var offset} -> List[Int]:
        if value == offset: raise StopIteration()
        return [value]
    _ = selected_again(predicate, iter(range(3)))
    _ = present_again(optional, iter(range(3)))
    _ = expanded_again(expand, iter(range(3)))
