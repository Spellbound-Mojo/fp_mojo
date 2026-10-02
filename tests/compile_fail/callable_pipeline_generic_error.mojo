# error: pipe: stage 1 should take Int, return Int and raise nothing
# error: raises callable_pipeline_generic_error.Failure
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var


def forward[R: Movable & Deinitable, E: Movable & Deinitable,
            A: Movable & Deinitable, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises E -> R where Fs.length >= 2:
    var result = pipe[E=E](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


@fieldwise_init
struct Failure(Movable):
    var code: Int


def increment(var value: Int) -> Int: return value + 1
def fail(var value: Int) raises Failure -> Int: raise Failure(value)


def main():
    var a = as_unary(increment)
    var b = as_unary(fail)
    _ = forward[Int, Never](1, a, b)
