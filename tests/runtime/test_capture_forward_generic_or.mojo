from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOrFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOrBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, B) raises E -> R](function: F, var a: A, ref b: B) -> Result[R,E]:
    return Capture[E].take(a^).borrow(b).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOrBox, b: CaptureForwardGenericOrBox) raises CaptureForwardGenericOrFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOrFault(calls)
    var a=CaptureForwardGenericOrBox(1)
    var b=CaptureForwardGenericOrBox(2)
    assert_equal(forward(callback, a^, b)._err().value.code,1)
    assert_equal(calls, 1)
