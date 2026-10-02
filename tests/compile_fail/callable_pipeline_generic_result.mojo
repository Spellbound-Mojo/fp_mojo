# error: constraint failed: forward: result type must equal R
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var


def forward[R: Movable & Deinitable, A: Movable & Deinitable,
            *Fs: Movable & Deinitable](var value: A, *functions: *Fs) -> R where Fs.length >= 2:
    var result = pipe[E=Never](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


def increment(var value: Int) -> Int: return value + 1


def main():
    var a = as_unary(increment)
    _ = forward[UInt](1, a, a)
