from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOrKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOrKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, B, /, var **options: K) raises E -> R](function: F, var a: A, ref b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).borrow(b).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOrKwBox, b: CaptureForwardGenericOrKwBox, /, var **options: Int) raises CaptureForwardGenericOrKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOrKwFault(calls)
    var a=CaptureForwardGenericOrKwBox(1)
    var b=CaptureForwardGenericOrKwBox(2)
    assert_equal(forward(callback, a^, b, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
