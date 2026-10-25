from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMrKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMrKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, B, /, var **options: K) raises E -> R](function: F, mut a: A, ref b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).borrow(b).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMrKwBox, b: CaptureForwardGenericMrKwBox, /, var **options: Int) raises CaptureForwardGenericMrKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMrKwFault(calls)
    var a=CaptureForwardGenericMrKwBox(1)
    var b=CaptureForwardGenericMrKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
