# error: expression does not designate a value with an origin
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
def callback(mut state:Token,var other:Token)->Int:
    state.value+=other.value
    return state.value
def main():
    var adapter=Capture[Never].stateful(callback,Token(1))
    _=adapter.run(adapter.state()^)
