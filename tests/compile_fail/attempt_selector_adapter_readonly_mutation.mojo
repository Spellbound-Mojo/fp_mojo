# error: invalid call to 'mutable'
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def update(mut value: Token) -> Int:
    value.value += 1
    return value.value

def check(value: Token):
    _ = Capture.mutable(value).run(update)

def main():
    check(Token(7))
