# error: uninitialized
from fp._binding_architecture import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int
def target(var value: Token) -> Int: return value.value
def main():
    var value = Token(3)
    _ = Capture[Never].consuming(target).run(value^)
    print(value.value)
