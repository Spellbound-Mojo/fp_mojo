# error: uninitialized value 'adapter'
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
def callback(mut state:Token,var text:String)->Int:return state.value+text.byte_length()
def main():
    var adapter=Capture[Never].stateful(callback,Token(1))
    _=adapter^.into_state()
    _=adapter.run(String("a"))
