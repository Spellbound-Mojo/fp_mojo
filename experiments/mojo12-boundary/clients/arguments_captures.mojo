from fp._argument_staged import Capture
from std.testing import assert_equal
@fieldwise_init
struct Fault(Movable):
    var code:Int
def main() raises:
    var calls=0
    def callback(mut state:Int,var text:String,/,var **options:Int) raises Fault {mut calls}->Int:
        calls+=1
        state+=text.byte_length()
        for item in options.items():state+=item.value
        if text.byte_length()==0:raise Fault(calls)
        return calls
    var state=0
    for n in range(1,4):assert_equal(Capture[Fault].kwargs(state,"a",extra=1).run(callback)._ok().value,n)
    assert_equal(Capture[Fault].kwargs[K=Int](state,"").run(callback)._err().value.code,4)
    assert_equal(calls,4)
    assert_equal(state,6)
