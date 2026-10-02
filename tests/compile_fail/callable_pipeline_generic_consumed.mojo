# error: use of uninitialized value
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var


def forward[R: Movable & Deinitable, A: Movable & Deinitable,
            *Fs: Movable & Deinitable](var value: A, *functions: *Fs) -> R where Fs.length >= 2:
    var result = pipe[E=Never](value^, *functions)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


@fieldwise_init
struct Token(Movable):
    var value: Int


def consume(var value: Token) -> Int: return value.value
def increment(var value: Int) -> Int: return value + 1


def main():
    var value = Token(4)
    var a = as_unary(consume)
    var b = as_unary(increment)
    _ = forward[Int](value^, a, b)
    _ = value.value
