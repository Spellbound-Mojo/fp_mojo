from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMrKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMrKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, B, /, var **options: K) raises E -> R](function: F, mut a: A, ref b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).borrow(b).kwargs(**options^).run(function)
def callback(mut a: CaptureGenericMrKwBox, b: CaptureGenericMrKwBox, /, var **options: Int) raises CaptureGenericMrKwFault -> Int:
    raise CaptureGenericMrKwFault(7)
def main() raises:
    var a=CaptureGenericMrKwBox(1)
    var b=CaptureGenericMrKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,7)
