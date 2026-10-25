# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOoConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOoConventionBox, var b: CaptureOoConventionBox) raises CaptureOoConventionFault -> Int:
    return 0
def main():
    var a=CaptureOoConventionBox(1)
    var b=CaptureOoConventionBox(2)
    _ = Capture[CaptureOoConventionFault].take(a^).take(b^).run(callback)
