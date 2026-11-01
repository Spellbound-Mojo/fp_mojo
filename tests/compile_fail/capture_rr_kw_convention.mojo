# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRrKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRrKwConventionBox, b: CaptureRrKwConventionBox, /, var **options: Int) raises CaptureRrKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureRrKwConventionBox(1)
    var b=CaptureRrKwConventionBox(2)
    _ = Capture[CaptureRrKwConventionFault].borrow(a).borrow(b).kwargs(extra=3).run(callback)
