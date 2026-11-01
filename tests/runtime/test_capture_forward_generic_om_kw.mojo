from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOmKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOmKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, mut B, /, var **options: K) raises E -> R](function: F, var a: A, mut b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].take(a^).mutable(b).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOmKwBox, mut b: CaptureForwardGenericOmKwBox, /, var **options: Int) raises CaptureForwardGenericOmKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOmKwFault(calls)
    var a=CaptureForwardGenericOmKwBox(1)
    var b=CaptureForwardGenericOmKwBox(2)
    assert_equal(forward(callback, a^, b, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
