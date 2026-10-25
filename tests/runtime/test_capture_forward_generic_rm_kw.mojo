from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRmKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRmKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, mut B, /, var **options: K) raises E -> R](function: F, ref a: A, mut b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).mutable(b).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRmKwBox, mut b: CaptureForwardGenericRmKwBox, /, var **options: Int) raises CaptureForwardGenericRmKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRmKwFault(calls)
    var a=CaptureForwardGenericRmKwBox(1)
    var b=CaptureForwardGenericRmKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
