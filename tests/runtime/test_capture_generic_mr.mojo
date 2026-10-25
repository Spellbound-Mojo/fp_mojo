from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMrFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMrBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, B) raises E -> R](function: F, mut a: A, ref b: B) -> Result[R,E]:
    return Capture[E].mutable(a).borrow(b).run(function)
def callback(mut a: CaptureGenericMrBox, b: CaptureGenericMrBox) raises CaptureGenericMrFault -> Int:
    raise CaptureGenericMrFault(7)
def main() raises:
    var a=CaptureGenericMrBox(1)
    var b=CaptureGenericMrBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,7)
