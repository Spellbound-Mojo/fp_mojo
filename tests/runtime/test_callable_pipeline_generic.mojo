"""Generic result equality with explicit error, independent of intermediate types."""
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var
from std.builtin.variadics import TypeList
from std.testing import assert_equal


def forward[R: Movable & Deinitable, E: Movable & Deinitable,
            A: Movable & Deinitable, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises E -> R where Fs.length >= 2:
    var result = pipe[E=E](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


def enclosing[R: Movable & Deinitable, E: Movable & Deinitable,
              A: Movable & Deinitable, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises E -> R where Fs.length >= 2:
    return forward[R, E](value^, *functions)


@fieldwise_init
struct ForwardFailure(Movable):
    var code: Int


def exercise(mode: Int, input_value: Int, fail_at: Int) -> Tuple[Int, Int, Int]:
    var first_calls = 0
    var second_calls = 0
    var last_calls = 0
    def first(var value: Int) raises ForwardFailure {mut first_calls, fail_at} -> String:
        first_calls += 1
        if fail_at == 1: raise ForwardFailure(100 + value)
        return String(value)
    def second(value: String) raises Never {mut second_calls} -> Int:
        second_calls += 1
        return value.byte_length()
    def last(var value: Int) raises ForwardFailure {mut last_calls, fail_at} -> Int:
        last_calls += 1
        if fail_at == 2: raise ForwardFailure(200 + value)
        return 3 * value + 5
    var a = as_unary(first)
    var b = as_unary(second)
    var c = as_unary(last)
    var value = 0
    var code = 0
    try:
        if mode == 0: value = last(second(first(input_value)))
        elif mode == 1: value = enclosing[Int, ForwardFailure](input_value, a, b, c)
        else:
            comptime Path = TypeList.of[Trait=Movable & Deinitable, String, Int, Int]()
            value = pipe[Path, ForwardFailure](input_value, a, b, c)
    except error: code = error.code
    return (value, code, first_calls * 100 + second_calls * 10 + last_calls)


def increment(var value: Int) -> Int: return value + 1
def never_increment(var value: Int) raises Never -> Int: return value + 1
def label(var value: Int) -> String: return String(value)
def size(value: String) -> Int: return value.byte_length()


# A generic wrapper forwards plain functions through thin signatures; the
# plain-function pipe overloads accept them without promotion.
def pure_forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable](
    var value: A, first: def(var A) raises E thin -> B, last: def(var B) raises E thin -> R
) raises E -> R:
    return pipe(value^, first, last)


def nonraising() -> Int:
    var a = as_unary(increment)
    var b = as_unary(never_increment)
    # Sixteen stages exercise a pack beyond the fixed signature control.
    return enclosing[Int, Never](0, a, b, a, b, a, b, a, b, a, b, a, b, a, b, a, b)


def stop(var value: Int) raises StopIteration -> Int:
    if value < 0: raise StopIteration()
    return value


def main() raises:
    for input_value in range(1, 125):
        var digits = 1 if input_value < 10 else 2 if input_value < 100 else 3
        for fail_at in range(3):
            var expected = (3 * digits + 5, 0, 111)
            if fail_at == 1: expected = (0, 100 + input_value, 100)
            elif fail_at == 2: expected = (0, 200 + digits, 111)
            for mode in range(3):
                assert_equal(exercise(mode, input_value, fail_at), expected)
    assert_equal(nonraising(), 16)
    assert_equal(pure_forward(123, label, size), 3)
    var s = as_unary(stop)
    var n = as_unary(never_increment)
    var caught = False
    try: _ = enclosing[Int, StopIteration](-1, n, s)
    except: caught = True
    assert_equal(caught, False)
    try: _ = enclosing[Int, StopIteration](-2, n, s)
    except: caught = True
    assert_equal(caught, True)
