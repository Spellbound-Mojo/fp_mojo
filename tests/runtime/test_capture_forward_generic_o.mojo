from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A) raises E -> R](function: F, var a: A) -> Result[R,E]:
    return Capture[E].take(a^).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOBox) raises CaptureForwardGenericOFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOFault(calls)
    var a=CaptureForwardGenericOBox(1)
    assert_equal(forward(callback, a^)._err().value.code,1)
    assert_equal(calls, 1)
