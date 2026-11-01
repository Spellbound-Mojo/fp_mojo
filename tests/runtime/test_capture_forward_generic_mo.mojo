from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMoFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMoBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, var B) raises E -> R](function: F, mut a: A, var b: B) -> Result[R,E]:
    return Capture[E].mutable(a).take(b^).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMoBox, var b: CaptureForwardGenericMoBox) raises CaptureForwardGenericMoFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMoFault(calls)
    var a=CaptureForwardGenericMoBox(1)
    var b=CaptureForwardGenericMoBox(2)
    assert_equal(forward(callback, a, b^)._err().value.code,1)
    assert_equal(calls, 1)
