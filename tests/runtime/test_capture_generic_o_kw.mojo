from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericOKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericOKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, /, var **options: K) raises E -> R](function: F, var a: A, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).kwargs(**options^).run(function)
def callback(var a: CaptureGenericOKwBox, /, var **options: Int) raises CaptureGenericOKwFault -> Int:
    raise CaptureGenericOKwFault(7)
def main() raises:
    var a=CaptureGenericOKwBox(1)
    assert_equal(forward(callback, a^, extra=3)._err().value.code,7)
