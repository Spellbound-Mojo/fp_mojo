from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericOrKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericOrKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, B, /, var **options: K) raises E -> R](function: F, var a: A, ref b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).borrow(b).kwargs(**options^).run(function)
def callback(var a: CaptureGenericOrKwBox, b: CaptureGenericOrKwBox, /, var **options: Int) raises CaptureGenericOrKwFault -> Int:
    raise CaptureGenericOrKwFault(7)
def main() raises:
    var a=CaptureGenericOrKwBox(1)
    var b=CaptureGenericOrKwBox(2)
    assert_equal(forward(callback, a^, b, extra=3)._err().value.code,7)
