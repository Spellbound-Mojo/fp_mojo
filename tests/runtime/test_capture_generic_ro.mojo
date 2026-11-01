from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRoFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRoBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, var B) raises E -> R](function: F, ref a: A, var b: B) -> Result[R,E]:
    return Capture[E].borrow(a).take(b^).run(function)
def callback(a: CaptureGenericRoBox, var b: CaptureGenericRoBox) raises CaptureGenericRoFault -> Int:
    raise CaptureGenericRoFault(7)
def main() raises:
    var a=CaptureGenericRoBox(1)
    var b=CaptureGenericRoBox(2)
    assert_equal(forward(callback, a, b^)._err().value.code,7)
