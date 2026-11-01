from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericOoKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericOoKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, var B, /, var **options: K) raises E -> R](function: F, var a: A, var b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).take(b^).kwargs(**options^).run(function)
def callback(var a: CaptureGenericOoKwBox, var b: CaptureGenericOoKwBox, /, var **options: Int) raises CaptureGenericOoKwFault -> Int:
    raise CaptureGenericOoKwFault(7)
def main() raises:
    var a=CaptureGenericOoKwBox(1)
    var b=CaptureGenericOoKwBox(2)
    assert_equal(forward(callback, a^, b^, extra=3)._err().value.code,7)
