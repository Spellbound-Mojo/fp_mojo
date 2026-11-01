# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOrKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOrKwConventionBox, b: CaptureOrKwConventionBox, /, var **options: Int) raises CaptureOrKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureOrKwConventionBox(1)
    var b=CaptureOrKwConventionBox(2)
    _ = Capture[CaptureOrKwConventionFault].take(a^).borrow(b).kwargs(extra=3).run(callback)
