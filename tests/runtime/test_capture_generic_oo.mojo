from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericOoFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericOoBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, var B) raises E -> R](function: F, var a: A, var b: B) -> Result[R,E]:
    return Capture[E].take(a^).take(b^).run(function)
def callback(var a: CaptureGenericOoBox, var b: CaptureGenericOoBox) raises CaptureGenericOoFault -> Int:
    raise CaptureGenericOoFault(7)
def main() raises:
    var a=CaptureGenericOoBox(1)
    var b=CaptureGenericOoBox(2)
    assert_equal(forward(callback, a^, b^)._err().value.code,7)
