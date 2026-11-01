from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRoFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRoBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, var B) raises E -> R](function: F, ref a: A, var b: B) -> Result[R,E]:
    return Capture[E].borrow(a).take(b^).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRoBox, var b: CaptureForwardGenericRoBox) raises CaptureForwardGenericRoFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRoFault(calls)
    var a=CaptureForwardGenericRoBox(1)
    var b=CaptureForwardGenericRoBox(2)
    assert_equal(forward(callback, a, b^)._err().value.code,1)
    assert_equal(calls, 1)
