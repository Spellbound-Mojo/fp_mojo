from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMKwBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, /, var **options: K) raises E -> R](function: F, mut a: A, /, var **options: K) -> Result[R,E]:
    return Capture[E].mutable(a).kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMKwBox, /, var **options: Int) raises CaptureForwardGenericMKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMKwFault(calls)
    var a=CaptureForwardGenericMKwBox(1)
    assert_equal(forward(callback, a, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
