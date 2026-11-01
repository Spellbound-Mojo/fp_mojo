# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureZeroKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroKwConventionBox(Movable):
    var value: Int
def callback(*, extra: Int) raises CaptureZeroKwConventionFault -> Int:
    return 0
def main():
    _ = Capture[CaptureZeroKwConventionFault].kwargs(extra=3).run(callback)
