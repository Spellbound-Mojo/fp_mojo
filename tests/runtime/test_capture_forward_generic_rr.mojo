from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRrFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRrBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, B) raises E -> R](function: F, ref a: A, ref b: B) -> Result[R,E]:
    return Capture[E].borrow(a).borrow(b).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRrBox, b: CaptureForwardGenericRrBox) raises CaptureForwardGenericRrFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRrFault(calls)
    var a=CaptureForwardGenericRrBox(1)
    var b=CaptureForwardGenericRrBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,1)
    assert_equal(calls, 1)
