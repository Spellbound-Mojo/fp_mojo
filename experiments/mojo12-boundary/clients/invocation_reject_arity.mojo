# error: no matching function
from fp._binding_state import Capture
@fieldwise_init
struct Fault(Movable):
    var code:Int
@fieldwise_init
struct Other(Movable):
    var code:Int
@fieldwise_init
struct Token(Movable):
    var value:Int
def bad(mut state:Token) raises Fault->Int:return 0
def main():
    _=Capture[Fault].stateful(bad,Token(1))
