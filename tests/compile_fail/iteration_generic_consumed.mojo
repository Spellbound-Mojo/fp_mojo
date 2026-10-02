# error: use of uninitialized value 'source'
from fp.iteration import MapIterator, map
from std.iter import Iterator, iter, next

def mapped[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
           F: def(var T) -> U](var function: F, var source: I) -> MapIterator[T, U, I, F] where I.Element == T:
    return map(function^, source^)


def mapped_again[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
                 F: def(var T) -> U](var function: F, var source: I) -> MapIterator[T, U, I, F] where I.Element == T:
    return mapped(function^, source^)


def main() raises:
    var values: List[Int] = [1, 2]
    var source = iter(values^)
    var calls = 0
    def transform(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + calls
    var adapter = mapped(transform, source^)
    _ = next(adapter)
    _ = next(source)
