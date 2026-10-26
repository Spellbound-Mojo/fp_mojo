# error: uninitialized value 'adapter'
from fp.data import Capture
@fieldwise_init
struct Fault(Movable):
    var code:Int
@fieldwise_init
struct Other(Movable):
    var code:Int
@fieldwise_init
struct Token(Movable):
    var value:Int
def callback(mut state:Token,var text:String)->Int:
    state.value+=text.byte_length()
    return state.value
def main():
    var pointer: def(mut Token, var String) thin -> Int = callback
    var adapter=Capture[Never]().stateful(pointer,Token(1))
    var view=Pointer(to=adapter.state())
    var moved=adapter^.into_state()
    print(view[].value)
    _=moved^
