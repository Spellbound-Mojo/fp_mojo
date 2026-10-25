from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, /, var **options: K) raises E -> R](function: F, ref a: A, /, var **options: K) -> Result[R,E]:
    return Capture[E].borrow(a).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRKwBox, /, var **options: Int) raises CaptureForwardGenericRKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRKwFault(calls)
    var a=CaptureForwardGenericRKwBox(1)
    assert_equal(forward(callback, a, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
