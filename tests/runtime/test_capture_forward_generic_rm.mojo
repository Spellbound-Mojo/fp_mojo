from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericRmFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericRmBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(A, mut B) raises E -> R](function: F, ref a: A, mut b: B) -> Result[R,E]:
    return Capture[E].borrow(a).mutable(b).run(function)
def main() raises:
    var calls = 0
    def callback(a: CaptureForwardGenericRmBox, mut b: CaptureForwardGenericRmBox) raises CaptureForwardGenericRmFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericRmFault(calls)
    var a=CaptureForwardGenericRmBox(1)
    var b=CaptureForwardGenericRmBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,1)
    assert_equal(calls, 1)
