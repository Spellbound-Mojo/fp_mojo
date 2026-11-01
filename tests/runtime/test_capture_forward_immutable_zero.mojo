from fp.data import Capture, Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardImmutableZeroSliceFault(Movable):
    var code:Int
def generic_capture[R: Movable & Deinitable, E: Movable & Deinitable, //, F: def() raises E -> R](function: F) -> Result[R, E]:
    return Capture[E]().run(function)
def main() raises:
    var bias = 2
    def source() raises CaptureForwardImmutableZeroSliceFault {bias} -> Int: raise CaptureForwardImmutableZeroSliceFault(bias)
    assert_equal(generic_capture(source)._err().value.code, 2)
