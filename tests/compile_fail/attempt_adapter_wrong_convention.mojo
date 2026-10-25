# Known Mojo 1.2 failure: crashes in native convention inference.
# Keep the expected diagnostic; a compiler crash is not a passing rejection.
# error: no matching function
from fp.data import mutating
@fieldwise_init
struct Token(Movable):
    var value: Int

def consume(var value: Token) -> Int:
    return value.value

def main():
    _ = mutating(consume)
