# error: invalid call to 'mapped'
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
    var calls = 0
    def transform(var value: Int) raises StopIteration {mut calls} -> Int:
        calls += 1
        if value == 2: raise StopIteration()
        return value
    var adapter = mapped(transform, iter(values^))
    _ = next(adapter)
