from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRrFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRrBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, B) raises E -> R](function: F, ref a: A, ref b: B) -> Result[R,E]:
    return Capture[E].borrow(a).borrow(b).run(function)
def callback(a: CaptureGenericRrBox, b: CaptureGenericRrBox) raises CaptureGenericRrFault -> Int:
    raise CaptureGenericRrFault(7)
def main() raises:
    var a=CaptureGenericRrBox(1)
    var b=CaptureGenericRrBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,7)
