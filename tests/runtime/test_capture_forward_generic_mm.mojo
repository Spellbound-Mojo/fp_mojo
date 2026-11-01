from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMmFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMmBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A, mut B) raises E -> R](function: F, mut a: A, mut b: B) -> Result[R,E]:
    return Capture[E].mutable(a).mutable(b).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMmBox, mut b: CaptureForwardGenericMmBox) raises CaptureForwardGenericMmFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMmFault(calls)
    var a=CaptureForwardGenericMmBox(1)
    var b=CaptureForwardGenericMmBox(2)
    assert_equal(forward(callback, a, b)._err().value.code,1)
    assert_equal(calls, 1)
