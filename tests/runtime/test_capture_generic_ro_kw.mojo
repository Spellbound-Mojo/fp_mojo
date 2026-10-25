from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRoKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRoKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, var B, /, var **options: K) raises E -> R](function: F, ref a: A, var b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).take(b^).kwargs(**options^).run(function)
def callback(a: CaptureGenericRoKwBox, var b: CaptureGenericRoKwBox, /, var **options: Int) raises CaptureGenericRoKwFault -> Int:
    raise CaptureGenericRoKwFault(7)
def main() raises:
    var a=CaptureGenericRoKwBox(1)
    var b=CaptureGenericRoKwBox(2)
    assert_equal(forward(callback, a, b^, extra=3)._err().value.code,7)
