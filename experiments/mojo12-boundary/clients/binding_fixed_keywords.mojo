from fp._binding_architecture import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Fault(Movable):
    var code: Int

def operation(mut state: Int, var text: String, *, scale: Int = 2) raises Fault -> Int:
    state += text.byte_length()
    if scale < 0: raise Fault(state)
    return state * scale
def main() raises:
    var scale = -1
    def bound(mut state: Int, var text: String) raises Fault {scale} -> Int:
        return operation(state, text^, scale=scale)
    def defaults(mut state: Int, var text: String) raises Fault -> Int:
        return operation(state, text^)
    var state = 1
    assert_equal(Capture[Fault].mut_owned(bound).run(state, String("abc"))._err().value.code, 4)
    assert_equal(Capture[Fault].mut_owned(defaults).run(state, String("a"))._ok().value, 10)
    assert_equal(state, 5)
