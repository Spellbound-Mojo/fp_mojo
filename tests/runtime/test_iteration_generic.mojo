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


def transferred[I: Iterator](var source: I) -> I: return source^


@fieldwise_init
struct Source(Iterator):
    comptime Element = Int
    var index: Int
    var length: Int
    var pulls: ArcPointer[Int]
    var trace: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        self.trace[] = self.trace[] * 10 + 1
        if self.index == self.length:
            self.index += 1
            raise StopIteration()
        self.index += 1
        return self.index


def exercise(mode: Int, length: Int, count: Int) raises:
    var pulls = ArcPointer(0)
    var trace = ArcPointer(0)
    var map_calls = 0
    var scan_calls = 0
    def label(var value: Int) {mut map_calls, trace} -> String:
        map_calls += 1
        trace[] = trace[] * 10 + 2
        return String(value * 11)
    def step(var total: Int, var value: String) {mut scan_calls, trace} -> Int:
        scan_calls += 1
        trace[] = trace[] * 10 + 3
        return total + value.byte_length()
    var source = Source(0, length, pulls, trace)
    var results = List[Int]()
    if mode == 0:
        var total = 7
        if count: results.append(total)
        for _ in range(1, count):
            total = step(total, label(next(source)))
            results.append(total)
        if count == length + 1:
            var stopped = False
            try: _ = next(source)
            except: stopped = True
            assert_equal(stopped, True)
    else:
        var output = scanned_again(step, 7, mapped_again(label, source^))
        assert_equal(pulls[], 0)
        assert_equal(map_calls, 0)
        assert_equal(scan_calls, 0)
        for _ in range(count):
            results.append(next(output))
            # Moving a partially consumed adapter must retain its progress.
            output = transferred(output^)
        if count == length + 1:
            for _ in range(3):
                var stopped = False
                try: _ = next(output)
                except: stopped = True
                assert_equal(stopped, True)
    var steps = max(count - 1, 0)
    var expected_trace = 0
    for _ in range(steps): expected_trace = expected_trace * 1000 + 123
    if count == length + 1: expected_trace = expected_trace * 10 + 1
    assert_equal(trace[], expected_trace)
    assert_equal(map_calls, steps)
    assert_equal(scan_calls, steps)
    assert_equal(pulls[], steps + Int(count == length + 1))
    assert_equal(len(results), count)
    for i in range(count): assert_equal(results[i], 7 + 2 * i)


def thin_map[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator](
    function: def(var T) thin -> U, var source: I
) -> MapIterator[T, U, I] where I.Element == T:
    return map(function, source^)


def thin_scan[A: Copyable & Deinitable, T: Movable & Deinitable, I: Iterator](
    function: def(var A, var T) thin -> A, var initial: A, var source: I
) -> ScanIterator[A, T, I] where I.Element == T:
    return scan_left(function, initial^, source^)


def double(var value: Int) -> Int: return value * 2
def add(var total: Int, var value: Int) -> Int: return total + value


def main() raises:
    for length in range(5):
        for count in range(length + 2):
            for mode in range(2): exercise(mode, length, count)
    var values: List[Int] = [1, 2, 3]
    var output = thin_scan(add, 0, thin_map(double, iter(values)))
    assert_equal(next(output), 0)
    assert_equal(next(output), 2)
    assert_equal(next(output), 6)
    assert_equal(next(output), 12)
    var left_calls = 0
    var right_calls = 0
    def left(var value: Int) {mut left_calls} -> Int:
        left_calls += 1
        return value + 10 * left_calls
    def right(var total: Int, var value: Int) {mut right_calls} -> Int:
        right_calls += 1
        return total + value + right_calls
    var a = mapped_again(left, iter(values))
    var b = scanned_again(right, 0, iter(values))
    assert_equal(next(a), 11)
    assert_equal(next(b), 0)
    assert_equal(next(b), 2)
    assert_equal(next(a), 22)
    assert_equal(next(b), 6)
    assert_equal(next(a), 33)
    assert_equal(next(b), 12)
    assert_equal(left_calls, 3)
    assert_equal(right_calls, 3)
    assert_equal(values, [1, 2, 3])
