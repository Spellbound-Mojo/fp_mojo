# error: origin_of(local)
"""Generic return annotations preserve native source origins and borrowed captures."""
from fp.iteration import MapIterator, ScanIterator, map, scan_left
from std.iter import Iterator, iter, next
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


def borrowed(values: List[Int]) -> List[Int].IteratorType[origin_of(values)]:
    return iter(values)

def origins(anchor: List[Int]) raises:
    var local: List[Int] = [4, 5]
    var calls = 0
    def callback(var value: Int) {imm anchor, mut calls} -> Int:
        calls += 1
        return value + anchor[0]
    var expected = mapped_again(callback, borrowed(anchor))
    assert_equal(next(expected), 2)
    var candidate = mapped_again(callback, borrowed(anchor))
    expected = candidate^
    assert_equal(next(expected), 2)
    def step(var total: Int, var value: Int) {imm anchor, mut calls} -> Int:
        calls += 1
        return total + value + anchor[0]
    var expected_scan = scanned_again(step, 0, borrowed(anchor))
    assert_equal(next(expected_scan), 0)
    var candidate_scan = scanned_again(step, 0, borrowed(local))
    expected_scan = candidate_scan^
    assert_equal(next(expected_scan), 0)
    assert_equal(next(expected_scan), 2)
    assert_equal(calls, 3)
    assert_equal(local, [4, 5])

def main() raises:
    var values: List[Int] = [1, 2]
    origins(values)
