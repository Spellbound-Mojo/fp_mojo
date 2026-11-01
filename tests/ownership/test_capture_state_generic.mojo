from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal

@fieldwise_init
struct CaptureStateGenericFault(Movable):
    var code:Int
def forward[S:Movable & Deinitable,A:Movable & Deinitable,R:Movable & Deinitable,E:Movable & Deinitable,//](function:def(mut S,var A) raises E thin -> R,var state:S,var value:A)->Result[R,E]:
    var adapter=Capture[E]().stateful(function,state^)
    return adapter.run(value^)
def f(mut state:Int,var text:String) raises CaptureStateGenericFault -> Int:
    state+=text.byte_length()
    raise CaptureStateGenericFault(state)
def main() raises:
    assert_equal(forward(f,1,String("ab"))._err().value.code,3)
