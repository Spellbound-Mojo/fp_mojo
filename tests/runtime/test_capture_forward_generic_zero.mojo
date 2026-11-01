from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericZeroFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericZeroBox(Movable):
    var value:Int
def forward[R: Movable & Deinitable, E: Movable & Deinitable, //, F: def() raises E -> R](function: F) -> Result[R,E]:
    return Capture[E]().run(function)
def main() raises:
    var calls = 0
    def callback() raises CaptureForwardGenericZeroFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericZeroFault(calls)
    assert_equal(forward(callback)._err().value.code,1)
    assert_equal(calls, 1)
