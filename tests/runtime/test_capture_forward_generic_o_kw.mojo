from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, /, var **options: K) raises E -> R](function: F, var a: A, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOKwBox, /, var **options: Int) raises CaptureForwardGenericOKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOKwFault(calls)
    var a=CaptureForwardGenericOKwBox(1)
    assert_equal(forward(callback, a^, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
