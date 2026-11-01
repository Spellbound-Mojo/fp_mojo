from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
def operation(mut state: Int, var text: String, *, scale: Int = 2) raises SliceFault -> Int:
    state += text.byte_length()
    if scale < 0: raise SliceFault(state)
    return state * scale
from fp.callables import OnceThunk
@fieldwise_init
struct SliceBound[o: MutOrigin](OnceThunk):
    var state: Pointer[Int, Self.o]
    var text: String
    comptime Out = Int
    comptime Error = SliceFault
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return operation(self.state[], self.text^, scale=-1)
def main() raises:
    var state = 1
    var work = SliceBound(Pointer(to=state), String("abc"))
    var outcome = attempt(work^)
    assert_equal(outcome._err().value.code, 4)
    assert_equal(state, 4)
