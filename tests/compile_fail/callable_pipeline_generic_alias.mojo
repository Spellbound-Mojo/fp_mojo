# error: aliasing values passed mutably
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var


def forward[R: Movable & Deinitable, A: Movable & Deinitable,
            *Fs: Movable & Deinitable](var value: A, *functions: *Fs) -> R where Fs.length >= 2:
    var result = pipe[E=Never](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


def main():
    var calls = 0
    def count(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + calls
    var a = as_unary(count)
    _ = forward[Int](1, a, a)
