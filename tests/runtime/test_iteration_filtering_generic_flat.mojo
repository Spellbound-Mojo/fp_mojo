"""Generic returned captured flat mapping follows outer/callback/inner order at every prefix."""
from fp.iteration import flat_map, filter, filter_map
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
struct Outer(Iterator):
    comptime Element = Int
    var index: Int
    var length: Int
    var trace: ArcPointer[List[Int]]
    def __next__(mut self) raises StopIteration -> Int:
        self.trace[].append(100 + self.index)
        if self.index == self.length: raise StopIteration()
        self.index += 1
        return self.index - 1

@fieldwise_init
struct Inner(Iterator):
    comptime Element = Int
    var owner: Int
    var index: Int
    var trace: ArcPointer[List[Int]]
    def __next__(mut self) raises StopIteration -> Int:
        self.trace[].append(300 + self.owner * 10 + self.index)
        if self.index == self.owner % 3: raise StopIteration()
        self.index += 1
        return self.owner * 10 + self.index - 1

def transfer[I: Iterator](var value: I) -> I: return value^

def exercise(library: Bool, length: Int, count: Int, complete: Bool,
             trace: ArcPointer[List[Int]]) raises -> List[Int]:
    var calls = 0
    def expand(var value: Int) {mut calls, trace} -> Inner:
        calls += 1
        trace[].append(200 + value)
        return Inner(value, 0, trace)
    var source = Outer(0, length, trace)
    var output = List[Int]()
    if library:
        var flattened = expanded_again(expand, source^)
        var forwarded = transfer(flattened^)
        assert_equal(calls, 0)
        assert_equal(len(trace[]), 0)
        for _ in range(count): output.append(next(forwarded))
        if complete:
            for _ in range(2):
                var exhausted = False
                try: _ = next(forwarded)
                except: exhausted = True
                assert_equal(exhausted, True)
    else:
        while len(output) < count or complete:
            var value: Int
            try: value = next(source)
            except: break
            var inner = expand(value)
            while len(output) < count or complete:
                var item: Int
                try: item = next(inner)
                except: break
                output.append(item)
    return output^

def main() raises:
    for length in range(7):
        var total = 0
        for i in range(length): total += i % 3
        for count in range(total + 1):
            var complete = count == total
            var expected = List[Int]()
            var trace = List[Int]()
            for i in range(length):
                if len(expected) == count and not complete: break
                trace.append(100 + i)
                trace.append(200 + i)
                var stopped = False
                for j in range(i % 3):
                    trace.append(300 + i * 10 + j)
                    expected.append(i * 10 + j)
                    if len(expected) == count and not complete:
                        stopped = True
                        break
                if stopped: break
                trace.append(300 + i * 10 + i % 3)
            if complete: trace.append(100 + length)
            for library in range(2):
                var observed = ArcPointer(List[Int]())
                assert_equal(exercise(Bool(library), length, count, complete, observed), expected)
                assert_equal(observed[], trace)
