"""Native cleanup of fold inputs, accumulators, callback state and typed errors."""
from fp.iteration import reduce, fold_until, EmptyReductionError, ReductionStepError
from fp.data import ControlFlow, Continue, Break
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct FoundationFoldCleanupToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct FoundationFoldCleanupFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct Source(Iterator):
    comptime Element = FoundationFoldCleanupToken
    var remaining: List[FoundationFoldCleanupToken]
    var state: FoundationFoldCleanupToken
    var trace: ArcPointer[List[Int]]
    def __next__(mut self) raises StopIteration -> FoundationFoldCleanupToken:
        self.state.value += 1
        self.trace[].append(self.state.value)
        if not self.remaining: raise StopIteration()
        return self.remaining.pop()

def exercise(library: Bool, mode: Int, length: Int, fail_at: Int, stop_at: Int,
             drops: ArcPointer[Int], errors: ArcPointer[Int], states: ArcPointer[Int],
             trace: ArcPointer[List[Int]]) -> Int:
    var remaining = List[FoundationFoldCleanupToken]()
    for i in range(length):
        remaining.append(FoundationFoldCleanupToken(length - i, drops))
    var source = Source(remaining^, FoundationFoldCleanupToken(0, states), trace)
    var state = FoundationFoldCleanupToken(0, states)
    def step(var acc: FoundationFoldCleanupToken, var item: FoundationFoldCleanupToken) raises FoundationFoldCleanupFailure {var state^, trace, errors, fail_at} -> FoundationFoldCleanupToken:
        state.value += 1
        trace[].append(1000 * state.value + 10 * acc.value + item.value)
        if item.value == fail_at: raise FoundationFoldCleanupFailure(item.value, errors)
        acc.value -= item.value
        return acc^
    var control_state = FoundationFoldCleanupToken(0, states)
    def control(var acc: FoundationFoldCleanupToken, var item: FoundationFoldCleanupToken) raises FoundationFoldCleanupFailure {var control_state^, trace, errors, fail_at, stop_at} -> ControlFlow[FoundationFoldCleanupToken, FoundationFoldCleanupToken]:
        control_state.value += 1
        trace[].append(1000 * control_state.value + 10 * acc.value + item.value)
        if item.value == fail_at: raise FoundationFoldCleanupFailure(item.value, errors)
        if item.value == stop_at: return ControlFlow[FoundationFoldCleanupToken, FoundationFoldCleanupToken](Break(acc^))
        acc.value -= item.value
        return ControlFlow[FoundationFoldCleanupToken, FoundationFoldCleanupToken](Continue(acc^))
    if library and mode == 1:
        try:
            var output = reduce(step, source^)
            return output.value
        except error:
            if error.isa[EmptyReductionError](): return -900
            var failure = error^.unwrap[ReductionStepError[FoundationFoldCleanupFailure]]().into_error()
            return -1000 - failure.code
    try:
        if library and mode == 0:
            var output = reduce(step, source^, initial=FoundationFoldCleanupToken(20, drops))
            return output.value
        if library:
            var output = fold_until(control, FoundationFoldCleanupToken(20, drops), source^)
            if output.isa[Break[FoundationFoldCleanupToken]]():
                return 2000 + output^.unwrap[Break[FoundationFoldCleanupToken]]().into_payload().value
            return output^.unwrap[Continue[FoundationFoldCleanupToken]]().into_payload().value
        var acc: FoundationFoldCleanupToken
        if mode == 1:
            try: acc = source.__next__()
            except: return -900
        else:
            acc = FoundationFoldCleanupToken(20, drops)
        while True:
            var item: FoundationFoldCleanupToken
            try: item = source.__next__()
            except: return acc.value
            if mode == 2:
                var output = control(acc^, item^)
                if output.isa[Break[FoundationFoldCleanupToken]]():
                    return 2000 + output^.unwrap[Break[FoundationFoldCleanupToken]]().into_payload().value
                acc = output^.unwrap[Continue[FoundationFoldCleanupToken]]().into_payload()
            else:
                acc = step(acc^, item^)
    except error:
        return -1000 - error.code

def main() raises:
    for mode in range(3):
        for length in range(5):
            for fail_at in range(6):
                for stop_at in range(6):
                    var results = List[Int]()
                    var traces = List[List[Int]]()
                    var error_counts = List[Int]()
                    for library in range(2):
                        var drops = ArcPointer(0)
                        var errors = ArcPointer(0)
                        var states = ArcPointer(0)
                        var trace = ArcPointer(List[Int]())
                        results.append(exercise(Bool(library), mode, length, fail_at, stop_at, drops, errors, states, trace))
                        assert_equal(drops[], length + (0 if mode == 1 else 1))
                        assert_equal(states[], 3)
                        error_counts.append(errors[])
                        traces.append(trace[].copy())
                    assert_equal(results[0], results[1])
                    assert_equal(error_counts[0], 1 if results[0] <= -1000 else 0)
                    assert_equal(error_counts[0], error_counts[1])
                    assert_equal(traces[0], traces[1])
