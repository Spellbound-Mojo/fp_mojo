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
def bad(mut first: Token, /, var **options: Int) -> Int: return 0
def main():
    var state=Token(1)
    _ = Capture[Fault].kwargs(state, Token(2), extra=3).run(bad)
