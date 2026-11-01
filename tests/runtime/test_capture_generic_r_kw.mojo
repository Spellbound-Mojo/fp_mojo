from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, /, var **options: K) raises E -> R](function: F, ref a: A, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).kwargs(**options^).run(function)
def callback(a: CaptureGenericRKwBox, /, var **options: Int) raises CaptureGenericRKwFault -> Int:
    raise CaptureGenericRKwFault(7)
def main() raises:
    var a=CaptureGenericRKwBox(1)
    assert_equal(forward(callback, a, extra=3)._err().value.code,7)
