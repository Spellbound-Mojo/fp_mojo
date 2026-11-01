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
def main():
    var bias=String("owned")
    def callback(mut state:Token,var text:String) raises Fault {var bias^}->Int:return state.value+bias.byte_length()+text.byte_length()
    _=Capture[Fault].stateful(callback,Token(1))
