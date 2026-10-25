# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRrConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRrConventionBox, b: CaptureRrConventionBox) raises CaptureRrConventionFault -> Int:
    return 0
def main():
    var a=CaptureRrConventionBox(1)
    var b=CaptureRrConventionBox(2)
    _ = Capture[CaptureRrConventionFault].borrow(a).borrow(b).run(callback)
