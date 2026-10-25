from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOoFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOoBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, var B) raises E -> R](function: F, var a: A, var b: B) -> Result[R,E]:
    return Capture[E].take(a^).take(b^).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOoBox, var b: CaptureForwardGenericOoBox) raises CaptureForwardGenericOoFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOoFault(calls)
    var a=CaptureForwardGenericOoBox(1)
    var b=CaptureForwardGenericOoBox(2)
    assert_equal(forward(callback, a^, b^)._err().value.code,1)
    assert_equal(calls, 1)
