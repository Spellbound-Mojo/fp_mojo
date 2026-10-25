from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericMmFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericMmBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, mut B) raises E -> R](function: F, mut a: A, mut b: B) -> Result[R,E]:
    return Capture[E].mutable(a).mutable(b).run(function)
def callback(mut a: CaptureGenericMmBox, mut b: CaptureGenericMmBox) raises CaptureGenericMmFault -> Int:
    raise CaptureGenericMmFault(7)
def main() raises:
    var a=CaptureGenericMmBox(1)
    var b=CaptureGenericMmBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,7)
