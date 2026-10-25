# error: use of uninitialized value
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextNativeConsumedCaptureSliceFault(Movable):
    var code: Int
def operation(mut state: Int, var text: String, *, scale: Int = 2) raises ContextNativeConsumedCaptureSliceFault -> Int:
    state += text.byte_length()
    if scale < 0: raise ContextNativeConsumedCaptureSliceFault(state)
    return state * scale
def main() raises:
    var state = 1
    var text = String("abc")
    def work() raises ContextNativeConsumedCaptureSliceFault {mut state, var text^} -> Int:
        return operation(state, text^, scale=-1)
    var code = 0
    try: _ = work()
    except error: code = error.code
    assert_equal(code, 4)
    assert_equal(state, 4)
