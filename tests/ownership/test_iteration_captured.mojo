"""Move-only payloads and persistent owned callback state; no capture copies."""
from fp.iteration import map
from std.iter import Iterator, next
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct IterationCapturedCounted(Copyable):
    var calls: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.calls = copy.calls
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct IterationCapturedToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Envelope(Movable):
    var value: IterationCapturedToken

@fieldwise_init
struct Source(Iterator):
    comptime Element = IterationCapturedToken
    var tokens: List[IterationCapturedToken]
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> IterationCapturedToken:
        self.pulls[] += 1
        if not self.tokens: raise StopIteration()
        return self.tokens.pop()

def exercise(library: Bool, length: Int, count: Int, copies: ArcPointer[Int],
             state_drops: ArcPointer[Int], value_drops: ArcPointer[Int],
             calls: ArcPointer[Int], pulls: ArcPointer[Int]) raises -> List[Int]:
    var state = IterationCapturedCounted(0, copies, state_drops)
    def transform(var value: IterationCapturedToken) {var state^, calls} -> Envelope:
        state.calls += 1
        calls[] += 1
        value.value += state.calls * 10
        return Envelope(value^)
    var values = List[IterationCapturedToken]()
    for i in range(length): values.append(IterationCapturedToken(length - i, value_drops))
    var source = Source(values^, pulls)
    var output = List[Int]()
    if library:
        var mapped = map(transform^, source^)
        assert_equal(copies[], 0)
        assert_equal(calls[], 0)
        assert_equal(pulls[], 0)
        for _ in range(count):
            var result = next(mapped)
            output.append(result.value.value)
    else:
        for _ in range(count):
            var result = transform(next(source))
            output.append(result.value.value)
    return output^

def main() raises:
    for length in range(5):
        for count in range(length + 1):
            for library in range(2):
                var copies = ArcPointer(0)
                var state_drops = ArcPointer(0)
                var value_drops = ArcPointer(0)
                var calls = ArcPointer(0)
                var pulls = ArcPointer(0)
                var output = exercise(Bool(library), length, count, copies, state_drops, value_drops, calls, pulls)
                var expected = List[Int]()
                for i in range(1, count + 1): expected.append(i * 11)
                assert_equal(output, expected)
                assert_equal(copies[], 0)
                assert_equal(state_drops[], 1)
                assert_equal(value_drops[], length)
                assert_equal(calls[], count)
                assert_equal(pulls[], count)
