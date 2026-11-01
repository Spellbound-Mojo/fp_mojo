# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOrConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOrConventionBox, b: CaptureOrConventionBox) raises CaptureOrConventionFault -> Int:
    return 0
def main():
    var a=CaptureOrConventionBox(1)
    var b=CaptureOrConventionBox(2)
    _ = Capture[CaptureOrConventionFault].take(a^).borrow(b).run(callback)
