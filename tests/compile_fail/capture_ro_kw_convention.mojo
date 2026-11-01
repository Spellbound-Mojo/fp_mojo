# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRoKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRoKwConventionBox, var b: CaptureRoKwConventionBox, /, var **options: Int) raises CaptureRoKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureRoKwConventionBox(1)
    var b=CaptureRoKwConventionBox(2)
    _ = Capture[CaptureRoKwConventionFault].borrow(a).take(b^).kwargs(extra=3).run(callback)
