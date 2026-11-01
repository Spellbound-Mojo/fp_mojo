# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOmConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOmConventionBox, mut b: CaptureOmConventionBox) raises CaptureOmConventionFault -> Int:
    return 0
def main():
    var a=CaptureOmConventionBox(1)
    var b=CaptureOmConventionBox(2)
    _ = Capture[CaptureOmConventionFault].take(a^).mutable(b).run(callback)
