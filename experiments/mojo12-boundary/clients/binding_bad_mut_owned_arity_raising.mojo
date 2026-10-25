# error: no matching function
# error: value passed to 'function' cannot be converted
from fp._binding_architecture import Capture
@fieldwise_init
struct Fault(Movable):
    var code: Int
@fieldwise_init
struct OtherFault(Movable):
    var code: Int
@fieldwise_init
struct Token(Movable):
    var value: Int
def bad(mut first: Token) raises Fault -> Int: return 0
def main():
    _ = Capture[Fault].mut_owned(bad)
