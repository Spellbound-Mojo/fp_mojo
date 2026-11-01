# error: invalid call to 'mutable'
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut value: Token) -> Int:
    value.value += 1
    return value.value

def owner(value: Token):
    _ = Capture.mutable(value).run(target)

def main():
    owner(Token(3))
