# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRmConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRmConventionBox, mut b: CaptureRmConventionBox) raises CaptureRmConventionFault -> Int:
    return 0
def main():
    var a=CaptureRmConventionBox(1)
    var b=CaptureRmConventionBox(2)
    _ = Capture[CaptureRmConventionFault].borrow(a).mutable(b).run(callback)
