from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureGenericZeroFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureGenericZeroBox(Movable):
    var value:Int
def forward[R: Movable & Deinitable, E: Movable & Deinitable, //, F: def() raises E -> R](function: F) -> Result[R,E]:
    return Capture[E]().run(function)
def callback() raises CaptureGenericZeroFault -> Int:
    raise CaptureGenericZeroFault(7)
def main() raises:
    assert_equal(forward(callback)._err().value.code,7)
