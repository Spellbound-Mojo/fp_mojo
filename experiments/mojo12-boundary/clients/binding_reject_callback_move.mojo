# error: use of uninitialized value 'target'
from fp._binding_architecture import Capture
@fieldwise_init
struct Token(Movable):
    var value: Int
def main():
    var value = Token(3)
    def target(var input: Token) {var value^} -> Int: return value.value + input.value
    var adapter = Capture[Never].consuming(target)
    var moved = target^
    _ = adapter.run(Token(1))
    _ = moved^
