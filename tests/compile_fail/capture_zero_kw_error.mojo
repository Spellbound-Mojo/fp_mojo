# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureZeroKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroKwErrorBox(Movable):
    var value: Int
def callback(var **options: Int) raises CaptureZeroKwErrorOther -> Int:
    return 0
def main():
    _ = Capture[CaptureZeroKwErrorFault].kwargs(extra=3).run(callback)
