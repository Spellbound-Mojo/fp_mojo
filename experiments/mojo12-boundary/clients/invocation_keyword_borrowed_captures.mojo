from fp._binding_staged import KeywordCall
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
    var adapter=KeywordCall[Int,String,Int,Fault].of(callback)
    var state=0
    for n in range(1,4):assert_equal(adapter.run(state,String("a"),extra=1)._ok().value,n)
    assert_equal(adapter.run(state,String())._err().value.code,4)
    assert_equal(calls,4)
    assert_equal(state,6)
