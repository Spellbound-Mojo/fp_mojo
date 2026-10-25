from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A) raises E -> R](function: F, ref a: A) -> Result[R,E]:
    return Capture[E].borrow(a).run(function)
def callback(a: CaptureGenericRBox) raises CaptureGenericRFault -> Int:
    raise CaptureGenericRFault(7)
def main() raises:
    var a=CaptureGenericRBox(1)
    assert_equal(forward(callback, a)._err().value.code,7)
