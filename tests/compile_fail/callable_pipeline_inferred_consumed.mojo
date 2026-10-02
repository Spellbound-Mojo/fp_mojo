# error: use of uninitialized value
from fp.functions import pipe, as_unary
@fieldwise_init
struct Token(Movable):
    var value: Int
def consume(var value: Token) -> Int: return value.value
def increment(var value: Int) -> Int: return value + 1
def main():
    var value = Token(4)
    var a = as_unary(consume)
    var b = as_unary(increment)
    _ = pipe(value^, a, b)
    _ = value.value
