from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericRmFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericRmBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, mut B) raises E -> R](function: F, ref a: A, mut b: B) -> Result[R,E]:
    return Capture[E].borrow(a).mutable(b).run(function)
def callback(a: CaptureGenericRmBox, mut b: CaptureGenericRmBox) raises CaptureGenericRmFault -> Int:
    raise CaptureGenericRmFault(7)
def main() raises:
    var a=CaptureGenericRmBox(1)
    var b=CaptureGenericRmBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,7)
