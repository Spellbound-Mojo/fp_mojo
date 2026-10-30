# error: invalid call to 'present_again'
from fp.iteration import FilterMapIterator, filter_map
from std.iter import Iterator, iter

def present[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, R: Movable & Deinitable, //,
            F: def(var T) -> R](
    var function: F, var source: I
) -> FilterMapIterator[T, U, I, F] where I.Element == T and R == Optional[U]:
    return filter_map(source^, function^)

def present_again[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, R: Movable & Deinitable, //,
                  F: def(var T) -> R](
    var function: F, var source: I
) -> FilterMapIterator[T, U, I, F] where I.Element == T and R == Optional[U]:
    return present(function^, source^)

def main():
    var offset = 1
    def nonoptional(var value: Int) {var offset} -> Int: return value + offset
    _ = present_again(nonoptional, iter(range(3)))
