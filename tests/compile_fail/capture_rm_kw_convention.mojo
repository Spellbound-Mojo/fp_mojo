# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRmKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureRmKwConventionBox, mut b: CaptureRmKwConventionBox, /, var **options: Int) raises CaptureRmKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureRmKwConventionBox(1)
    var b=CaptureRmKwConventionBox(2)
    _ = Capture[CaptureRmKwConventionFault].borrow(a).mutable(b).kwargs(extra=3).run(callback)
