# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOConventionBox) raises CaptureOConventionFault -> Int:
    return 0
def main():
    var a=CaptureOConventionBox(1)
    _ = Capture[CaptureOConventionFault].take(a^).run(callback)
