# error: aliasing values passed mutably
from fp.data import attempt
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut first: Token, var second: Token, /, var **values: Int) -> Int:
    first.value += second.value
    return first.value

def main():
    var value = Token(3)
    _ = attempt(target, value, value^, one=7)
