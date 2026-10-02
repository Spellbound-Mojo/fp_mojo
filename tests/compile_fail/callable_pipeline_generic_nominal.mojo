# error: constraint failed: forward: result type must equal R
# Distinct nominal results remain distinct even when their layouts are identical.
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var


@fieldwise_init
struct First(Movable):
    var value: Int


@fieldwise_init
struct Second(Movable):
    var value: Int


def forward[R: Movable & Deinitable, A: Movable & Deinitable,
            *Fs: Movable & Deinitable](var value: A, *functions: *Fs) -> R where Fs.length >= 2:
    var result = pipe[E=Never](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


def wrap(var value: Int) -> First: return First(value)
def keep(var value: First) -> First: return value^


def main():
    var a = as_unary(wrap)
    var b = as_unary(keep)
    _ = forward[Second](1, a, b)
