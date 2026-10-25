from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, /, var **options: K) raises E -> R](function: F, mut a: A, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).kwargs(**options^).run(function)
def callback(mut a: CaptureGenericMKwBox, /, var **options: Int) raises CaptureGenericMKwFault -> Int:
    raise CaptureGenericMKwFault(7)
def main() raises:
    var a=CaptureGenericMKwBox(1)
    assert_equal(forward(callback, a, extra=3)._err().value.code,7)
