"""Return lazy adapters through generic functions with public native type aliases."""
from fp.iteration import MapIterator, ScanIterator, map, scan_left
from std.iter import Iterator, iter, next
from std.testing import assert_equal


def mapped[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
           F: def(var T) -> U](var function: F, var source: I) -> MapIterator[T, U, I, F] where I.Element == T:
    return map(function^, source^)


def scanned[A: Copyable & Deinitable, T: Movable & Deinitable, I: Iterator, //,
            F: def(var A, var T) -> A](var function: F, var initial: A, var source: I) -> ScanIterator[A, T, I, F] where I.Element == T:
    return scan_left(function^, initial^, source^)


def main() raises:
    var map_calls = 0
    var scan_calls = 0
    def double(var value: Int) {mut map_calls} -> Int:
        map_calls += 1
        return value * 2
    def add(var total: Int, var value: Int) {mut scan_calls} -> Int:
        scan_calls += 1
        return total + value
    var values: List[Int] = [1, 2, 3]
    var transformed = mapped(double, iter(values))
    var running = scanned(add, 0, transformed^)
    assert_equal(map_calls, 0)
    assert_equal(scan_calls, 0)
    assert_equal(next(running), 0)
    assert_equal(map_calls, 0)
    assert_equal(scan_calls, 0)
    assert_equal(next(running), 2)
    assert_equal(next(running), 6)
    assert_equal(map_calls, 2)
    assert_equal(scan_calls, 2)
    # Abandon the last element without forcing its evaluation.
    _ = running^
    assert_equal(map_calls, 2)
    assert_equal(scan_calls, 2)
    assert_equal(values, [1, 2, 3])
    print("generic lazy snapshots: 0, 2, 6; source preserved")
