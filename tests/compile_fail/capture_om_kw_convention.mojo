# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOmKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOmKwConventionBox, mut b: CaptureOmKwConventionBox, /, var **options: Int) raises CaptureOmKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureOmKwConventionBox(1)
    var b=CaptureOmKwConventionBox(2)
    _ = Capture[CaptureOmKwConventionFault].take(a^).mutable(b).kwargs(extra=3).run(callback)
