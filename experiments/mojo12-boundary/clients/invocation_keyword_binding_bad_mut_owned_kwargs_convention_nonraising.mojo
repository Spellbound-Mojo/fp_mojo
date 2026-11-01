# error: no matching function
# error: value passed to 'function' cannot be converted
from fp._binding_staged import KeywordCall
@fieldwise_init
struct Fault(Movable):
    var code: Int
@fieldwise_init
struct OtherFault(Movable):
    var code: Int
@fieldwise_init
struct Token(Movable):
    var value: Int
def bad(var first: Token, var second: Token, /, var **options: Int) -> Int: return 0
def main():
    _ = KeywordCall[Token, Token, Int, Fault].of(bad)
