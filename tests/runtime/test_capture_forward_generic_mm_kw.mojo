from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMmKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMmKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, mut B, /, var **options: K) raises E -> R](function: F, mut a: A, mut b: B, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).mutable(b).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMmKwBox, mut b: CaptureForwardGenericMmKwBox, /, var **options: Int) raises CaptureForwardGenericMmKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMmKwFault(calls)
    var a=CaptureForwardGenericMmKwBox(1)
    var b=CaptureForwardGenericMmKwBox(2)
    assert_equal(forward(callback, a, b, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
