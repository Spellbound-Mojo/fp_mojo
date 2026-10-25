# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRKwConventionBox, /, var **options: Int) raises CaptureRKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureRKwConventionBox(1)
    _ = Capture[CaptureRKwConventionFault].borrow(a).kwargs(extra=3).run(callback)
