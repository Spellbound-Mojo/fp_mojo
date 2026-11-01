from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRoKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRoKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, var B, /, var **options: K) raises E -> R](function: F, ref a: A, var b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).take(b^).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRoKwBox, var b: CaptureForwardGenericRoKwBox, /, var **options: Int) raises CaptureForwardGenericRoKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRoKwFault(calls)
    var a=CaptureForwardGenericRoKwBox(1)
    var b=CaptureForwardGenericRoKwBox(2)
    assert_equal(forward(callback, a, b^, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
