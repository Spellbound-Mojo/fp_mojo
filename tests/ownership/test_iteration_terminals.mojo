"""Native-reference terminal pulls, closure state, move-only errors and cleanup."""
from fp.iteration import find, any, all, collect_list
from std.iter import Iterator, iter
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct IterationTerminalsToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct IterationTerminalsFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct Source(Iterator):
    comptime Element = IterationTerminalsToken
    var remaining: List[IterationTerminalsToken]
    var trace: ArcPointer[List[Int]]
    def __next__(mut self) raises StopIteration -> IterationTerminalsToken:
        self.trace[].append(10)
        if not self.remaining: raise StopIteration()
        return self.remaining.pop()

def exercise(library: Bool, mode: Int, length: Int, target: Int, fail_at: Int,
             drops: ArcPointer[Int], states: ArcPointer[Int], errors: ArcPointer[Int],
             trace: ArcPointer[List[Int]]) -> Int:
    var remaining = List[IterationTerminalsToken]()
    for i in range(length):
        remaining.append(IterationTerminalsToken(length - i, drops))
    var source = Source(remaining^, trace)
    var state = IterationTerminalsToken(0, states)
    def predicate(item: IterationTerminalsToken) raises IterationTerminalsFailure {var state^, trace, target, fail_at, errors} -> Bool:
        state.value += 1
        trace[].append(100 * state.value + item.value)
        if item.value == fail_at: raise IterationTerminalsFailure(item.value, errors)
        return item.value == target
    try:
        if library:
            if mode == 0:
                var output = find(predicate, source^)
                return output.value().value if output else -1
            if mode == 1: return Int(any(predicate, source^))
            return Int(all(predicate, source^))
        while True:
            var item: IterationTerminalsToken
            try: item = source.__next__()
            except: return -1 if mode == 0 else Int(mode == 2)
            var selected = predicate(item)
            if mode == 0 and selected: return item.value
            if mode == 1 and selected: return 1
            if mode == 2 and not selected: return 0
    except failure:
        return -1000 - failure.code

def stop(item: Int) raises StopIteration -> Bool:
    raise StopIteration()

def main() raises:
    for mode in range(3):
        for length in range(5):
            for target in range(6):
                for fail_at in range(6):
                    var results = List[Int]()
                    var traces = List[List[Int]]()
                    for library in range(2):
                        var drops = ArcPointer(0)
                        var states = ArcPointer(0)
                        var errors = ArcPointer(0)
                        var trace = ArcPointer(List[Int]())
                        var output = exercise(Bool(library), mode, length, target, fail_at, drops, states, errors, trace)
                        assert_equal(drops[], length)
                        assert_equal(states[], 1)
                        assert_equal(errors[], 1 if output <= -1000 else 0)
                        results.append(output)
                        traces.append(trace[].copy())
                    assert_equal(results[0], results[1])
                    assert_equal(traces[0], traces[1])
    # A callback StopIteration must not become ordinary source exhaustion.
    for mode in range(3):
        var caught = False
        try:
            if mode == 0: _ = find(stop, iter(range(1)))
            elif mode == 1: _ = any(stop, iter(range(1)))
            else: _ = all(stop, iter(range(1)))
        except: caught = True
        assert_equal(caught, True)
    # Non-raising stateful closures and empty identities use the pure overloads.
    var calls = 0
    def even(value: Int) {mut calls} -> Bool:
        calls += 1
        return value % 2 == 0
    var found = find(even, iter(range(1, 6)))
    assert_equal(found.take(), 2)
    assert_equal(calls, 2)
    assert_equal(any(even, iter(range(0))), False)
    assert_equal(all(even, iter(range(0))), True)
    assert_equal(calls, 2)
    assert_equal(any(even, iter(range(1, 6))), True)
    assert_equal(all(even, iter(range(1, 6))), False)
    assert_equal(calls, 5)
    var drops = ArcPointer(0)
    var values: List[IterationTerminalsToken] = [IterationTerminalsToken(1, drops), IterationTerminalsToken(2, drops)]
    var collected = collect_list(iter(values^))
    assert_equal(drops[], 0)
    assert_equal(collected[1].value, 2)
    collected.clear()
    assert_equal(drops[], 2)
