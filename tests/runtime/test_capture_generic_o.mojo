from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericOFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericOBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A) raises E -> R](function: F, var a: A) -> Result[R,E]:
    return Capture[E].take(a^).run(function)
def callback(var a: CaptureGenericOBox) raises CaptureGenericOFault -> Int:
    raise CaptureGenericOFault(7)
def main() raises:
    var a=CaptureGenericOBox(1)
    assert_equal(forward(callback, a^)._err().value.code,7)
