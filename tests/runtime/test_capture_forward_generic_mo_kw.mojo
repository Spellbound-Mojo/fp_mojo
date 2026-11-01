from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMoKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMoKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, var B, /, var **options: K) raises E -> R](function: F, mut a: A, var b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).take(b^).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMoKwBox, var b: CaptureForwardGenericMoKwBox, /, var **options: Int) raises CaptureForwardGenericMoKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMoKwFault(calls)
    var a=CaptureForwardGenericMoKwBox(1)
    var b=CaptureForwardGenericMoKwBox(2)
    assert_equal(forward(callback, a, b^, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
