"""Generic returned captured filtering matches direct loops at every output prefix, including tail rejection."""
from fp.iteration import filter, filter_map, flat_map
from std.iter import next
from std.memory import ArcPointer
from std.testing import assert_equal

from fp.iteration import FilterIterator, FilterMapIterator, FlatMapIterator
from std.iter import Iterator, IterableOwned

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

def exercise(library: Bool, optional: Bool, length: Int, bias: Int, count: Int,
             complete: Bool, trace: ArcPointer[List[Int]]) raises -> List[String]:
    var calls = 0
    def predicate(value: Int) {mut calls, bias, trace} -> Bool:
        calls += 1
        trace[].append(200 + calls)
        return (value + bias) % 3 == 0
    def transform(var value: Int) {mut calls, bias, trace} -> Optional[String]:
        calls += 1
        trace[].append(200 + calls)
        if (value + bias) % 3: return None
        return Optional(String(value) + ":" + String(calls))
    var source = Source(0, length, trace)
    var output = List[String]()
    if library:
        if optional:
            var selected = present_again(transform, source^)
            assert_equal(calls, 0)
            assert_equal(len(trace[]), 0)
            for _ in range(count): output.append(next(selected))
            if complete:
                for _ in range(2):
                    var exhausted = False
                    try: _ = next(selected)
                    except: exhausted = True
                    assert_equal(exhausted, True)
        else:
            var selected = selected_again(predicate, source^)
            assert_equal(calls, 0)
            assert_equal(len(trace[]), 0)
            for _ in range(count): output.append(String(next(selected)))
            if complete:
                for _ in range(2):
                    var exhausted = False
                    try: _ = next(selected)
                    except: exhausted = True
                    assert_equal(exhausted, True)
    else:
        while len(output) < count or complete:
            var value: Int
            try: value = next(source)
            except: break
            if optional:
                var mapped = transform(value)
                if mapped: output.append(mapped.take())
            elif predicate(value): output.append(String(value))
    return output^

def main() raises:
    for length in range(7):
        for bias in range(3):
            var matches = List[Int]()
            for i in range(1, length + 1):
                if (i + bias) % 3 == 0: matches.append(i)
            for count in range(len(matches) + 1):
                for optional in range(2):
                    var complete = count == len(matches)
                    var needed = length if complete else (matches[count - 1] if count else 0)
                    var expected_trace = List[Int]()
                    for i in range(needed):
                        expected_trace.append(100 + i)
                        expected_trace.append(201 + i)
                    if complete: expected_trace.append(100 + length)
                    var expected = List[String]()
                    for i in range(count):
                        var value = String(matches[i])
                        if optional: value += ":" + String(matches[i])
                        expected.append(value^)
                    for library in range(2):
                        var trace = ArcPointer(List[Int]())
                        assert_equal(exercise(Bool(library), Bool(optional), length, bias, count, complete, trace), expected)
                        assert_equal(trace[], expected_trace)
