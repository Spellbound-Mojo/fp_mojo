from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOoKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOoKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, var B, /, var **options: K) raises E -> R](function: F, var a: A, var b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).take(b^).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOoKwBox, var b: CaptureForwardGenericOoKwBox, /, var **options: Int) raises CaptureForwardGenericOoKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOoKwFault(calls)
    var a=CaptureForwardGenericOoKwBox(1)
    var b=CaptureForwardGenericOoKwBox(2)
    assert_equal(forward(callback, a^, b^, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
