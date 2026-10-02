"""Generic lazy factories preserve types, prefixes, fusion and interleaved state."""
from fp.iteration import MapIterator, ScanIterator, map, scan_left
from std.iter import Iterator, iter, next
from std.memory import ArcPointer
from std.testing import assert_equal


def mapped[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
           F: def(var T) -> U](var function: F, var source: I) -> MapIterator[T, U, I, F] where I.Element == T:
    return map(function^, source^)


def mapped_again[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
                 F: def(var T) -> U](var function: F, var source: I) -> MapIterator[T, U, I, F] where I.Element == T:
    return mapped(function^, source^)


def scanned[A: Copyable & Deinitable, T: Movable & Deinitable, I: Iterator, //,
            F: def(var A, var T) -> A](var function: F, var initial: A, var source: I) -> ScanIterator[A, T, I, F] where I.Element == T:
    return scan_left(function^, initial^, source^)


def scanned_again[A: Copyable & Deinitable, T: Movable & Deinitable, I: Iterator, //,
                  F: def(var A, var T) -> A](var function: F, var initial: A, var source: I) -> ScanIterator[A, T, I, F] where I.Element == T:
    return scanned(function^, initial^, source^)


@fieldwise_init
struct First(Copyable):
    var value: Int

@fieldwise_init
struct Second(Copyable):
    var value: Int

def convert(var value: First) -> Int: return value.value
def accumulate(var total: Int, var value: First) -> Int: return total + value.value

def main() raises:
    comptime assert First != Second
    var values = List[First]()
    values.append(First(3))
    var mapped = mapped_again(convert, iter(values))
    var scanned = scanned_again(accumulate, 1, iter(values))
    assert_equal(next(mapped), 3)
    assert_equal(next(scanned), 1)
    assert_equal(next(scanned), 4)
