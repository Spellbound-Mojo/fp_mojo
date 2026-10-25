from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRmKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRmKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, mut B, /, var **options: K) raises E -> R](function: F, ref a: A, mut b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).mutable(b).kwargs(**options^).run(function)
def callback(a: CaptureGenericRmKwBox, mut b: CaptureGenericRmKwBox, /, var **options: Int) raises CaptureGenericRmKwFault -> Int:
    raise CaptureGenericRmKwFault(7)
def main() raises:
    var a=CaptureGenericRmKwBox(1)
    var b=CaptureGenericRmKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,7)
