# error: value passed to mutable argument 'value' must be mutable
from fp._binding_architecture import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int
def target(mut value: Token) -> Int:
    value.value += 1
    return value.value
def check(value: Token):
    _ = Capture[Never].mutating(target).run(value)
def main(): check(Token(3))
