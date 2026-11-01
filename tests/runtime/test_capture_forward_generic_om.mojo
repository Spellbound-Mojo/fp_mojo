from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericOmFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericOmBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A, mut B) raises E -> R](function: F, var a: A, mut b: B) -> Result[R,E]:
    return Capture[E].take(a^).mutable(b).run(function)
def main() raises:
    var calls = 0
    def callback(var a: CaptureForwardGenericOmBox, mut b: CaptureForwardGenericOmBox) raises CaptureForwardGenericOmFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericOmFault(calls)
    var a=CaptureForwardGenericOmBox(1)
    var b=CaptureForwardGenericOmBox(2)
    assert_equal(forward(callback, a^, b)._err().value.code,1)
    assert_equal(calls, 1)
