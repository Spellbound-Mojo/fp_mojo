"""Compare inferred/explicit pipes with direct native calls at every failure position."""
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct CallablePipelineInferredCleanupToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Envelope(Movable):
    var token: CallablePipelineInferredCleanupToken
    def take(deinit self) -> CallablePipelineInferredCleanupToken: return self.token^

@fieldwise_init
struct InferredFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def exercise(mode: Int, fail_at: Int, drops: ArcPointer[Int],
             states: ArcPointer[Int], errors: ArcPointer[Int],
             trace: ArcPointer[List[Int]]) -> Int:
    var state = CallablePipelineInferredCleanupToken(0, states)
    def first(var value: CallablePipelineInferredCleanupToken) raises InferredFailure {var state^, trace, fail_at, errors} -> Envelope:
        state.value += 1
        trace[].append(100 + state.value)
        if fail_at == 1: raise InferredFailure(11, errors)
        return Envelope(value^)
    def second(var value: Envelope) raises InferredFailure {trace, fail_at, errors} -> CallablePipelineInferredCleanupToken:
        trace[].append(200 + value.token.value)
        if fail_at == 2: raise InferredFailure(22, errors)
        return value^.take()
    def third(var value: CallablePipelineInferredCleanupToken) raises InferredFailure {trace, fail_at, errors} -> Int:
        trace[].append(300 + value.value)
        if fail_at == 3: raise InferredFailure(33, errors)
        return value.value
    var a = as_unary(first^)
    var b = as_unary(second^)
    var c = as_unary(third^)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Envelope, CallablePipelineInferredCleanupToken, Int]()
    var total = 0
    for i in range(1, 4):
        try:
            if mode == 3: total += pipe(CallablePipelineInferredCleanupToken(i, drops), a, b, c)
            elif mode == 2: total += pipe[E=InferredFailure](CallablePipelineInferredCleanupToken(i, drops), a, b, c)
            elif mode == 1: total += pipe[Path, InferredFailure](CallablePipelineInferredCleanupToken(i, drops), a, b, c)
            else: total += c(b(a(CallablePipelineInferredCleanupToken(i, drops))))
        except error: total -= error.code
    return total

def main() raises:
    for fail_at in range(4):
        var outputs = List[Int]()
        var traces = List[List[Int]]()
        for mode in range(4):
            var drops = ArcPointer(0)
            var states = ArcPointer(0)
            var errors = ArcPointer(0)
            var trace = ArcPointer(List[Int]())
            outputs.append(exercise(mode, fail_at, drops, states, errors, trace))
            traces.append(trace[].copy())
            assert_equal(drops[], 3)
            assert_equal(states[], 1)
            assert_equal(errors[], 3 if fail_at else 0)
        assert_equal(outputs[0], outputs[1])
        assert_equal(traces[0], traces[1])
        assert_equal(outputs[1], -33 * fail_at if fail_at else 6)
        assert_equal(outputs[0], outputs[2])
        assert_equal(traces[0], traces[2])
        assert_equal(outputs[0], outputs[3])
        assert_equal(traces[0], traces[3])
