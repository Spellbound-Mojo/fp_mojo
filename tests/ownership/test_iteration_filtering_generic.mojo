"""Generic returned captured predicates borrow move-only values; selection, absence and abandonment clean up once."""
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
struct Capture(Copyable):
    var offset: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.offset = copy.offset
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct IterationFilteringGenericToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Source(Iterator):
    comptime Element = IterationFilteringGenericToken
    var values: List[IterationFilteringGenericToken]
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> IterationFilteringGenericToken:
        self.pulls[] += 1
        if not self.values: raise StopIteration()
        return self.values.pop()

def exercise_selected_again(library: Bool, length: Int, count: Int, copies: ArcPointer[Int],
                    state_drops: ArcPointer[Int], drops: ArcPointer[Int],
                    calls: ArcPointer[Int], pulls: ArcPointer[Int]) raises -> List[Int]:
    var state = Capture(0, copies, state_drops)
    def callback(value: IterationFilteringGenericToken) {var state^, calls} -> Bool:
        calls[] += 1
        return (value.value + state.offset) % 2 == 0
    var values = List[IterationFilteringGenericToken]()
    for i in range(length): values.append(IterationFilteringGenericToken(length - i, drops))
    var source = Source(values^, pulls)
    var output = List[Int]()
    if library:
        var selected = selected_again(callback^, source^)
        assert_equal(copies[], 0)
        assert_equal(calls[], 0)
        assert_equal(pulls[], 0)
        for _ in range(count):
            var value = next(selected)
            output.append(value.value)
    else:
        while len(output) < count:
            var value = next(source)
            if callback(value): output.append(value.value)
    return output^

def exercise_present_again(library: Bool, length: Int, count: Int, copies: ArcPointer[Int],
                    state_drops: ArcPointer[Int], drops: ArcPointer[Int],
                    calls: ArcPointer[Int], pulls: ArcPointer[Int]) raises -> List[Int]:
    var state = Capture(0, copies, state_drops)
    def callback(var value: IterationFilteringGenericToken) {var state^, calls} -> Optional[IterationFilteringGenericToken]:
        calls[] += 1
        if (value.value + state.offset) % 2: return None
        value.value += 100
        return Optional(value^)
    var values = List[IterationFilteringGenericToken]()
    for i in range(length): values.append(IterationFilteringGenericToken(length - i, drops))
    var source = Source(values^, pulls)
    var output = List[Int]()
    if library:
        var selected = present_again(callback^, source^)
        assert_equal(copies[], 0)
        assert_equal(calls[], 0)
        assert_equal(pulls[], 0)
        for _ in range(count):
            var value = next(selected)
            output.append(value.value)
    else:
        while len(output) < count:
            var selected = callback(next(source))
            if selected:
                var value = selected.take()
                output.append(value.value)
    return output^

def main() raises:
    for length in range(7):
        for count in range(length // 2 + 1):
            for mode in range(2):
                for library in range(2):
                    var copies = ArcPointer(0)
                    var state_drops = ArcPointer(0)
                    var drops = ArcPointer(0)
                    var calls = ArcPointer(0)
                    var pulls = ArcPointer(0)
                    var values: List[Int]
                    if mode:
                        values = exercise_present_again(Bool(library), length, count, copies, state_drops, drops, calls, pulls)
                    else:
                        values = exercise_selected_again(Bool(library), length, count, copies, state_drops, drops, calls, pulls)
                    var expected = List[Int]()
                    for i in range(1, count + 1): expected.append(i * 2 + (100 if mode else 0))
                    assert_equal(values, expected)
                    assert_equal(copies[], 0)
                    assert_equal(state_drops[], 1)
                    assert_equal(drops[], length)
                    assert_equal(calls[], count * 2)
                    assert_equal(pulls[], count * 2)
