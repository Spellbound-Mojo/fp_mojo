"""Common error inference versus explicit metadata, direct calls and a scalar model."""
from fp.functions import as_unary, pipe
from std.builtin.variadics import TypeList
from std.testing import assert_equal
from std.memory import ArcPointer

@fieldwise_init
struct PipelineFailure(Movable):
    var code: Int

def exercise(mode: Int, fail_at: Int, input_value: Int) -> Tuple[Int, Int, Int]:
    var trace = ArcPointer(0)
    def first(var value: Int) raises PipelineFailure {trace, fail_at} -> String:
        trace[] = trace[] * 10 + 1
        if fail_at == 1: raise PipelineFailure(101 + value)
        return String(value)
    def neutral(value: String) raises Never {trace} -> Int:
        trace[] = trace[] * 10 + 2
        return value.byte_length()
    def second(var value: Int) raises PipelineFailure {trace, fail_at} -> Int:
        trace[] = trace[] * 10 + 3
        if fail_at == 2: raise PipelineFailure(202 + value)
        return value * 2
    def pure(var value: Int) {trace} -> Int:
        trace[] = trace[] * 10 + 4
        return value + 5
    def third(var value: Int) raises PipelineFailure {trace, fail_at} -> Int:
        trace[] = trace[] * 10 + 5
        if fail_at == 3: raise PipelineFailure(303 + value)
        return value * 3
    var a = as_unary(first)
    var b = as_unary(neutral)
    var c = as_unary(second)
    var d = as_unary(pure)
    var e = as_unary(third)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, String, Int, Int, Int, Int]()
    var value = 0
    var code = 0
    try:
        if mode == 3: value = pipe(input_value, a, b, c, d, e)
        elif mode == 2: value = pipe[E=PipelineFailure](input_value, a, b, c, d, e)
        elif mode == 1: value = pipe[Path, PipelineFailure](input_value, a, b, c, d, e)
        else: value = third(pure(second(neutral(first(input_value)))))
    except error: code = error.code
    return (value, code, trace[])

def add(var value: Int) raises PipelineFailure -> Int:
    if value == 9: raise PipelineFailure(909)
    return value + 1

def pure_add(var value: Int) -> Int: return value + 1

def propagate() raises PipelineFailure -> Int:
    var a = as_unary(add)
    var p = as_unary(pure_add)
    # The first inhabited error is at index 15, beyond the old small arities.
    return pipe(-6, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, a)

def main() raises:
    for input_value in range(1, 125):
        var digits = 1 if input_value < 10 else 2 if input_value < 100 else 3
        for fail_at in range(4):
            var expected = (3 * (2 * digits + 5), 0, 12345)
            if fail_at == 1: expected = (0, 101 + input_value, 1)
            elif fail_at == 2: expected = (0, 202 + digits, 123)
            elif fail_at == 3: expected = (0, 303 + 2 * digits + 5, 12345)
            for mode in range(4):
                assert_equal(exercise(mode, fail_at, input_value), expected)
    var caught = False
    try: _ = propagate()
    except error:
        caught = True
        assert_equal(error.code, 909)
    assert_equal(caught, True)
