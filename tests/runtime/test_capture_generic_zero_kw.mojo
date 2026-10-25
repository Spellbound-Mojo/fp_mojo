from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericZeroKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericZeroKwBox(Movable):
    var value:Int
def forward[K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var **options: K) raises E -> R](function: F, /, var **options: K) -> Result[R,E]:
    return Capture[E].kwargs(**options^).run(function)
def callback(var **options: Int) raises CaptureGenericZeroKwFault -> Int:
    raise CaptureGenericZeroKwFault(7)
def main() raises:
    assert_equal(forward(callback, extra=3)._err().value.code,7)
