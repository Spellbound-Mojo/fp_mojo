from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRrKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRrKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, B, /, var **options: K) raises E -> R](function: F, ref a: A, ref b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).borrow(b).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRrKwBox, b: CaptureForwardGenericRrKwBox, /, var **options: Int) raises CaptureForwardGenericRrKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRrKwFault(calls)
    var a=CaptureForwardGenericRrKwBox(1)
    var b=CaptureForwardGenericRrKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
