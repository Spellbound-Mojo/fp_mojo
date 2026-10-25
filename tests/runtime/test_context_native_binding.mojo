from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextNativeBindingSliceFault(Movable):
    var code: Int
def operation(mut state: Int, var text: String, *, scale: Int = 2) raises ContextNativeBindingSliceFault -> Int:
    state += text.byte_length()
    if scale < 0: raise ContextNativeBindingSliceFault(state)
    return state * scale
from fp.callables import OnceThunk
@fieldwise_init
struct ContextNativeBindingSliceBound[o: MutOrigin](OnceThunk):
    var state: Pointer[Int, Self.o]
    var text: String
    comptime Out = Int
    comptime Error = ContextNativeBindingSliceFault
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return operation(self.state[], self.text^, scale=-1)
def main() raises:
    var state = 1
    var work = ContextNativeBindingSliceBound(Pointer(to=state), String("abc"))
    var outcome = Capture[Never]().run(work^)
    assert_equal(outcome._err().value.code, 4)
    assert_equal(state, 4)
