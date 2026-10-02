"""Native reference for heterogeneous moves, state, typed failures and cleanup."""
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct CallablePipelineCleanupToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Envelope(Movable):
    var token: CallablePipelineCleanupToken
    def take(deinit self) -> CallablePipelineCleanupToken: return self.token^

@fieldwise_init
struct CallablePipelineCleanupFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def exercise(library: Bool, fail_at: Int, drops: ArcPointer[Int],
             states: ArcPointer[Int], errors: ArcPointer[Int],
             trace: ArcPointer[List[Int]]) -> Int:
    var state = CallablePipelineCleanupToken(0, states)
    def first(var value: CallablePipelineCleanupToken) raises CallablePipelineCleanupFailure {var state^, trace, fail_at, errors} -> Envelope:
        state.value += 1
        trace[].append(100 + state.value)
        if fail_at == 1: raise CallablePipelineCleanupFailure(11, errors)
        return Envelope(value^)
    def second(var value: Envelope) raises CallablePipelineCleanupFailure {trace, fail_at, errors} -> CallablePipelineCleanupToken:
        trace[].append(200 + value.token.value)
        if fail_at == 2: raise CallablePipelineCleanupFailure(22, errors)
        return value^.take()
    def third(var value: CallablePipelineCleanupToken) raises CallablePipelineCleanupFailure {trace, fail_at, errors} -> Int:
        trace[].append(300 + value.value)
        if fail_at == 3: raise CallablePipelineCleanupFailure(33, errors)
        return value.value
    var a = as_unary(first^)
    var b = as_unary(second^)
    var c = as_unary(third^)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Envelope, CallablePipelineCleanupToken, Int]()
    var total = 0
    for i in range(1, 4):
        try:
            if library: total += pipe[Path, CallablePipelineCleanupFailure](CallablePipelineCleanupToken(i, drops), a, b, c)
            else: total += c(b(a(CallablePipelineCleanupToken(i, drops))))
        except error: total -= error.code
    return total

def main() raises:
    for fail_at in range(4):
        var outputs = List[Int]()
        var traces = List[List[Int]]()
        for library in range(2):
            var drops = ArcPointer(0)
            var states = ArcPointer(0)
            var errors = ArcPointer(0)
            var trace = ArcPointer(List[Int]())
            outputs.append(exercise(Bool(library), fail_at, drops, states, errors, trace))
            traces.append(trace[].copy())
            assert_equal(drops[], 3)
            assert_equal(states[], 1)
            assert_equal(errors[], 3 if fail_at else 0)
        assert_equal(outputs[0], outputs[1])
        assert_equal(traces[0], traces[1])
        assert_equal(outputs[1], -33 * fail_at if fail_at else 6)
