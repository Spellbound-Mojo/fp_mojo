# error: no matching function in call to 'attempt'
from fp.data import attempt
@fieldwise_init
struct Token(Movable):
    var value: Int

def update(mut value: Token) -> Int:
    value.value += 1
    return value.value

def check(value: Token):
    _ = attempt[mutable=True](update, value)

def main():
    check(Token(7))
