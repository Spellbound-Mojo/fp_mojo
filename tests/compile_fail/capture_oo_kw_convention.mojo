# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOoKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOoKwConventionBox, var b: CaptureOoKwConventionBox, /, var **options: Int) raises CaptureOoKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureOoKwConventionBox(1)
    var b=CaptureOoKwConventionBox(2)
    _ = Capture[CaptureOoKwConventionFault].take(a^).take(b^).kwargs(extra=3).run(callback)
