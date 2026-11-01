from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMrFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMrBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, B) raises E -> R](function: F, mut a: A, ref b: B) -> Result[R,E]:
    return Capture[E].mutable(a).borrow(b).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMrBox, b: CaptureForwardGenericMrBox) raises CaptureForwardGenericMrFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMrFault(calls)
    var a=CaptureForwardGenericMrBox(1)
    var b=CaptureForwardGenericMrBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,1)
    assert_equal(calls, 1)
