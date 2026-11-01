# error: invalid call to 'mutable'
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int

def target(mut value: Token, /, var **values: Int) -> Int:
    value.value += 1
    return value.value

def owner(value: Token):
    _ = Capture.mutable(value).kwargs(one=7).run(target)

def main():
    owner(Token(3))
