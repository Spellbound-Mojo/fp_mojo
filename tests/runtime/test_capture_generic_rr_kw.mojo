from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRrKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRrKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, B, /, var **options: K) raises E -> R](function: F, ref a: A, ref b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).borrow(b).kwargs(**options^).run(function)
def callback(a: CaptureGenericRrKwBox, b: CaptureGenericRrKwBox, /, var **options: Int) raises CaptureGenericRrKwFault -> Int:
    raise CaptureGenericRrKwFault(7)
def main() raises:
    var a=CaptureGenericRrKwBox(1)
    var b=CaptureGenericRrKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,7)
