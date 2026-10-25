# error: cannot be converted from 'String' to 'Token'
from fp._binding_architecture import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int
def target(var value: Token) -> Int: return value.value
def main():
    _ = Capture[Never].consuming(target).run(String("wrong"))
