"""Captured mapping agrees with a direct loop at every consumed prefix."""
from fp.iteration import map
from std.iter import Iterator, next
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Source(Iterator):
    comptime Element = Int
    var index: Int
    var length: Int
    var trace: ArcPointer[List[Int]]
    def __next__(mut self) raises StopIteration -> Int:
        self.trace[].append(100 + self.index)
        if self.index == self.length: raise StopIteration()
        self.index += 1
        return self.index

def exercise(library: Bool, length: Int, count: Int, trace: ArcPointer[List[Int]]) raises -> List[String]:
    var calls = 0
    def transform(var value: Int) {mut calls, trace} -> String:
        calls += 1
        trace[].append(200 + calls)
        return String(value) + ":" + String(calls)
    var source = Source(0, length, trace)
    var output = List[String]()
    if library:
        var mapped = map(transform, source^)
        assert_equal(len(trace[]), 0)
        assert_equal(calls, 0)
        for _ in range(count): output.append(next(mapped))
        if count == length:
            for _ in range(2):
                var exhausted = False
                try: _ = next(mapped)
                except: exhausted = True
                assert_equal(exhausted, True)
    else:
        for _ in range(count):
            var input = next(source)
            output.append(transform(input))
        if count == length:
            var exhausted = False
            try: _ = next(source)
            except: exhausted = True
            assert_equal(exhausted, True)
    assert_equal(calls, count)
    return output^

def main() raises:
    for length in range(6):
        for count in range(length + 1):
            var direct_trace = ArcPointer(List[Int]())
            var mapped_trace = ArcPointer(List[Int]())
            var direct = exercise(False, length, count, direct_trace)
            var mapped = exercise(True, length, count, mapped_trace)
            var expected = List[String]()
            var expected_trace = List[Int]()
            for i in range(1, count + 1):
                expected.append(String(i) + ":" + String(i))
                expected_trace.append(99 + i)
                expected_trace.append(200 + i)
            if count == length: expected_trace.append(100 + length)
            assert_equal(direct, expected)
            assert_equal(mapped, expected)
            assert_equal(direct_trace[], expected_trace)
            assert_equal(mapped_trace[], expected_trace)
