# error: cannot implicitly convert
# error: value to 'R'
from fp.functions import as_unary, pipe


def forward[A: Movable & Deinitable, B: Movable & Deinitable,
            R: Movable & Deinitable,
            F: def(var A) -> B, G: def(var B) -> R](
    var value: A, first: F, last: G
) -> R:
    return pipe[E=Never](value^, first, last)


def label(var value: Int) -> String: return String(value)
def size(value: String) -> Int: return value.byte_length()


def main():
    var a = as_unary(label)
    var b = as_unary(size)
    _ = forward(123, a, b)
