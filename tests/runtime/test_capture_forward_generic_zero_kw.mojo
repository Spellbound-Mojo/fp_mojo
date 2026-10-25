from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureForwardGenericZeroKwFault(Movable):
    var code:Int
@fieldwise_init
struct CaptureForwardGenericZeroKwBox(Movable):
    var value:Int
def forward[K: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var **options: K) raises E -> R](function: F, /, var **options: K) -> Result[R,E]:
    return Capture[E].kwargs(**options^).run(function)
def main() raises:
    var calls = 0
    def callback(var **options: Int) raises CaptureForwardGenericZeroKwFault {mut calls} -> Int:
        calls += 1
        raise CaptureForwardGenericZeroKwFault(calls)
    assert_equal(forward(callback, extra=3)._err().value.code,1)
    assert_equal(calls, 1)
