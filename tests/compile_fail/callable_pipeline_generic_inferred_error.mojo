# error: cannot call function that may raise
# error: in context that supports an error type of 'E'
from fp.functions import as_unary, pipe
from std.builtin.rebind import rebind_var


def forward[A: Movable & Deinitable, B: Movable & Deinitable,
            R: Movable & Deinitable, E: Movable & Deinitable,
            F: def(var A) raises E -> B, G: def(var B) raises E -> R](
    var value: A, first: F, last: G
) raises E -> R:
    var result = pipe(value^, first, last)
    comptime assert type_of(result) == R, "forward: result type must equal R"
    return rebind_var[R](result^)


@fieldwise_init
struct Failure(Movable):
    var code: Int


def label(var value: Int) raises Failure -> String:
    if value < 0: raise Failure(value)
    return String(value)


def size(value: String) raises Failure -> Int: return value.byte_length()


def main():
    var a = as_unary(label)
    var b = as_unary(size)
    try: _ = forward(123, a, b)
    except: pass
