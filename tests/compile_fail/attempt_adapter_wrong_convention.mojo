# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
# error: no matching function
from fp.data import mutating
@fieldwise_init
struct Token(Movable):
    var value: Int

def consume(var value: Token) -> Int:
    return value.value

def main():
    _ = mutating[F=type_of(consume)](consume)
