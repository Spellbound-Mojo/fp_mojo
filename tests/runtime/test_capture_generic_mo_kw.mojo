from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMoKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMoKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, var B, /, var **options: K) raises E -> R](function: F, mut a: A, var b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).take(b^).kwargs(**options^).run(function)
def callback(mut a: CaptureGenericMoKwBox, var b: CaptureGenericMoKwBox, /, var **options: Int) raises CaptureGenericMoKwFault -> Int:
    raise CaptureGenericMoKwFault(7)
def main() raises:
    var a=CaptureGenericMoKwBox(1)
    var b=CaptureGenericMoKwBox(2)
    assert_equal(forward(callback, a, b^, extra=3)._err().value.code,7)
