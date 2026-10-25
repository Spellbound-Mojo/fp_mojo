# error: no matching method
# error: value passed to 'function' cannot be converted
from fp._argument_staged import Capture
@fieldwise_init
struct Fault(Movable):
    var code: Int
@fieldwise_init
struct OtherFault(Movable):
    var code: Int
@fieldwise_init
struct Token(Movable):
    var value: Int
def bad(mut first: Token, /, var **options: Int) raises Fault -> Int: return 0
def main():
    var state=Token(1)
    _ = Capture[Fault].kwargs[K=Int](state, Token(2)).run(bad)
