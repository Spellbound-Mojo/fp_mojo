"""Captured predicates borrow move-only values; selection, absence and abandonment clean up once."""
from fp.iteration import filter, filter_map
from std.iter import Iterator, next
from std.memory import ArcPointer
from std.testing import assert_equal

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
struct IterationFilteringCapturedToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Source(Iterator):
    comptime Element = IterationFilteringCapturedToken
    var values: List[IterationFilteringCapturedToken]
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> IterationFilteringCapturedToken:
        self.pulls[] += 1
        if not self.values: raise StopIteration()
        return self.values.pop()

def exercise_filter(library: Bool, length: Int, count: Int, copies: ArcPointer[Int],
                    state_drops: ArcPointer[Int], drops: ArcPointer[Int],
                    calls: ArcPointer[Int], pulls: ArcPointer[Int]) raises -> List[Int]:
    var state = Capture(0, copies, state_drops)
    def callback(value: IterationFilteringCapturedToken) {var state^, calls} -> Bool:
        calls[] += 1
        return (value.value + state.offset) % 2 == 0
    var values = List[IterationFilteringCapturedToken]()
    for i in range(length): values.append(IterationFilteringCapturedToken(length - i, drops))
    var source = Source(values^, pulls)
    var output = List[Int]()
    if library:
        var selected = filter(callback^, source^)
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

def exercise_filter_map(library: Bool, length: Int, count: Int, copies: ArcPointer[Int],
                    state_drops: ArcPointer[Int], drops: ArcPointer[Int],
                    calls: ArcPointer[Int], pulls: ArcPointer[Int]) raises -> List[Int]:
    var state = Capture(0, copies, state_drops)
    def callback(var value: IterationFilteringCapturedToken) {var state^, calls} -> Optional[IterationFilteringCapturedToken]:
        calls[] += 1
        if (value.value + state.offset) % 2: return None
        value.value += 100
        return Optional(value^)
    var values = List[IterationFilteringCapturedToken]()
    for i in range(length): values.append(IterationFilteringCapturedToken(length - i, drops))
    var source = Source(values^, pulls)
    var output = List[Int]()
    if library:
        var selected = filter_map(callback^, source^)
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
                        values = exercise_filter_map(Bool(library), length, count, copies, state_drops, drops, calls, pulls)
                    else:
                        values = exercise_filter(Bool(library), length, count, copies, state_drops, drops, calls, pulls)
                    var expected = List[Int]()
                    for i in range(1, count + 1): expected.append(i * 2 + (100 if mode else 0))
                    assert_equal(values, expected)
                    assert_equal(copies[], 0)
                    assert_equal(state_drops[], 1)
                    assert_equal(drops[], length)
                    assert_equal(calls[], count * 2)
                    assert_equal(pulls[], count * 2)
