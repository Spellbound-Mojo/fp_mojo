from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericOmKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericOmKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, mut B, /, var **options: K) raises E -> R](function: F, var a: A, mut b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).mutable(b).kwargs(**options^).run(function)
def callback(var a: CaptureGenericOmKwBox, mut b: CaptureGenericOmKwBox, /, var **options: Int) raises CaptureGenericOmKwFault -> Int:
    raise CaptureGenericOmKwFault(7)
def main() raises:
    var a=CaptureGenericOmKwBox(1)
    var b=CaptureGenericOmKwBox(2)
    assert_equal(forward(callback, a^, b, extra=3)._err().value.code,7)
