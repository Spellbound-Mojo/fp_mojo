from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMoFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMoBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, var B) raises E -> R](function: F, mut a: A, var b: B) -> Result[R,E]:
    return Capture[E].mutable(a).take(b^).run(function)
def callback(mut a: CaptureGenericMoBox, var b: CaptureGenericMoBox) raises CaptureGenericMoFault -> Int:
    raise CaptureGenericMoFault(7)
def main() raises:
    var a=CaptureGenericMoBox(1)
    var b=CaptureGenericMoBox(2)
    assert_equal(forward(callback, a, b^)._err().value.code,7)
