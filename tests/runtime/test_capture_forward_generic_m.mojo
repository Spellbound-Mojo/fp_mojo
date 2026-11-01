from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericMFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericMBox(Movable):
    var value:Int
def forward[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(mut A) raises E -> R](function: F, mut a: A) -> Result[R,E]:
    return Capture[E].mutable(a).run(function)
def main() raises:
    var calls = 0
    def callback(mut a: CaptureForwardGenericMBox) raises CaptureForwardGenericMFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericMFault(calls)
    var a=CaptureForwardGenericMBox(1)
    assert_equal(forward(callback, a)._err().value.code,1)
    assert_equal(calls, 1)
