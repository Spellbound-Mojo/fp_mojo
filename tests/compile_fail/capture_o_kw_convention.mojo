# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOKwConventionBox(Movable):
    var value: Int
def callback(mut a: CaptureOKwConventionBox, /, var **options: Int) raises CaptureOKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureOKwConventionBox(1)
    _ = Capture[CaptureOKwConventionFault].take(a^).kwargs(extra=3).run(callback)
