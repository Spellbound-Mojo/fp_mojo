from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMmKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMmKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, mut B, /, var **options: K) raises E -> R](function: F, mut a: A, mut b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).mutable(b).kwargs(**options^).run(function)
def callback(mut a: CaptureGenericMmKwBox, mut b: CaptureGenericMmKwBox, /, var **options: Int) raises CaptureGenericMmKwFault -> Int:
    raise CaptureGenericMmKwFault(7)
def main() raises:
    var a=CaptureGenericMmKwBox(1)
    var b=CaptureGenericMmKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,7)
