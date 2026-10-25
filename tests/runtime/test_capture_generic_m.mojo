from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A) raises E -> R](function: F, mut a: A) -> Result[R,E]:
    return Capture[E].mutable(a).run(function)
def callback(mut a: CaptureGenericMBox) raises CaptureGenericMFault -> Int:
    raise CaptureGenericMFault(7)
def main() raises:
    var a=CaptureGenericMBox(1)
    assert_equal(forward(callback, a)._err().value.code,7)
