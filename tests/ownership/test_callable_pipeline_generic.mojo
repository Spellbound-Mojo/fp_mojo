"""Generic forwarding preserves borrowed captures, moves, copies and cleanup."""
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var
from std.builtin.variadics import TypeList
from std.memory import ArcPointer
from std.testing import assert_equal


def forward[R: Movable & Deinitable, E: Movable & Deinitable,
            A: Movable & Deinitable, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises E -> R where Fs.length >= 2:
    var result = pipe[E=E](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


@fieldwise_init
struct Input(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct Middle(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct Output(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct CallablePipelineGenericFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct Owner(Copyable):
    var value: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1


def exercise(mode: Int, fail_at: Int, drops: ArcPointer[Int],
             error_drops: ArcPointer[Int], copies: ArcPointer[Int],
             owner_drops: ArcPointer[Int]) raises:
    var owner = Owner(3, copies, owner_drops)
    var trace = ArcPointer(0)
    var first_calls = 0
    def first(var value: Input) raises CallablePipelineGenericFailure {mut first_calls, imm owner, trace, drops, error_drops, fail_at} -> Middle:
        first_calls += 1
        trace[] = trace[] * 10 + 1
        if fail_at == 1: raise CallablePipelineGenericFailure(value.value + 100, error_drops)
        return Middle(value.value + owner.value, drops)
    def second(var value: Middle) raises Never {trace} -> Int:
        trace[] = trace[] * 10 + 2
        return value.value * 2
    def third(var value: Int) raises CallablePipelineGenericFailure {trace, drops, error_drops, fail_at} -> Output:
        trace[] = trace[] * 10 + 3
        if fail_at == 2: raise CallablePipelineGenericFailure(value + 200, error_drops)
        return Output(value + 5, drops)
    def fourth(var value: Output) {trace} -> Output:
        trace[] = trace[] * 10 + 4
        value.value *= 3
        return value^
    def last(var value: Output) raises CallablePipelineGenericFailure {trace, error_drops, fail_at} -> Output:
        trace[] = trace[] * 10 + 5
        if fail_at == 3: raise CallablePipelineGenericFailure(value.value + 300, error_drops)
        return value^
    var a = as_unary(first)
    var b = as_unary(second)
    var c = as_unary(third)
    var d = as_unary(fourth)
    var e = as_unary(last)
    for input_value in range(1, 5):
        trace[] = 0
        var observed = 0
        var code = 0
        try:
            var result: Output
            if mode == 0: result = last(fourth(third(second(first(Input(input_value, drops))))))
            elif mode == 1: result = forward[Output, CallablePipelineGenericFailure](Input(input_value, drops), a, b, c, d, e)
            else:
                comptime Path = TypeList.of[Trait=Movable & Deinitable, Middle, Int, Output, Output, Output]()
                result = pipe[Path, CallablePipelineGenericFailure](Input(input_value, drops), a, b, c, d, e)
            observed = result.value
        except error: code = error.code
        var expected = 3 * (2 * (input_value + 3) + 5)
        assert_equal(observed, expected if fail_at == 0 else 0)
        assert_equal(code, 0 if fail_at == 0 else input_value + 100 if fail_at == 1 else 2 * (input_value + 3) + 200 if fail_at == 2 else expected + 300)
        assert_equal(trace[], 1 if fail_at == 1 else 123 if fail_at == 2 else 12345)
        assert_equal(drops[], input_value * (1 if fail_at == 1 else 2 if fail_at == 2 else 3))
        assert_equal(error_drops[], 0 if fail_at == 0 else input_value)
    assert_equal(first_calls, 4)
    assert_equal(copies[], 0)
    # Keep a later use: native destruction may occur immediately after last use.
    assert_equal(owner_drops[], 0)
    assert_equal(owner.value, 3)


def borrowed(value: Owner) -> Int: return value.value
def increment(var value: Int) -> Int: return value + 1


def main() raises:
    for mode in range(3):
        for fail_at in range(4):
            var drops = ArcPointer(0)
            var error_drops = ArcPointer(0)
            var copies = ArcPointer(0)
            var owner_drops = ArcPointer(0)
            exercise(mode, fail_at, drops, error_drops, copies, owner_drops)
            assert_equal(copies[], 0)
            assert_equal(owner_drops[], 1)
    var copies = ArcPointer(0)
    var drops = ArcPointer(0)
    var a = as_unary(borrowed)
    var b = as_unary(increment)
    assert_equal(forward[Int, Never](Owner(7, copies, drops), a, b), 8)
    assert_equal(copies[], 0)
    assert_equal(drops[], 1)
