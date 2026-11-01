from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericOmFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericOmBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, mut B) raises E -> R](function: F, var a: A, mut b: B) -> Result[R,E]:
    return Capture[E].take(a^).mutable(b).run(function)
def callback(var a: CaptureGenericOmBox, mut b: CaptureGenericOmBox) raises CaptureGenericOmFault -> Int:
    raise CaptureGenericOmFault(7)
def main() raises:
    var a=CaptureGenericOmBox(1)
    var b=CaptureGenericOmBox(2)
    assert_equal(forward(callback, a^, b)._err().value.code,7)
