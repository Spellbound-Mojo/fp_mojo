# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRoConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRoConventionBox, var b: CaptureRoConventionBox) raises CaptureRoConventionFault -> Int:
    return 0
def main():
    var a=CaptureRoConventionBox(1)
    var b=CaptureRoConventionBox(2)
    _ = Capture[CaptureRoConventionFault].borrow(a).take(b^).run(callback)
