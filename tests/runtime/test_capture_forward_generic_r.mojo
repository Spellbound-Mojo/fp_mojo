from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A) raises E -> R](function: F, ref a: A) -> Result[R,E]:
    return Capture[E].borrow(a).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRBox) raises CaptureForwardGenericRFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRFault(calls)
    var a=CaptureForwardGenericRBox(1)
    assert_equal(forward(callback, a)._err().value.code,1)
    assert_equal(calls, 1)
