# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRConventionBox) raises CaptureRConventionFault -> Int:
    return 0
def main():
    var a=CaptureRConventionBox(1)
    _ = Capture[CaptureRConventionFault].borrow(a).run(callback)
