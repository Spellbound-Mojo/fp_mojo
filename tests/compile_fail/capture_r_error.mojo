# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRErrorBox(Movable):
    var value: Int
def callback(a: CaptureRErrorBox) raises CaptureRErrorOther -> Int:
    return 0
def main():
    var a=CaptureRErrorBox(1)
    _ = Capture[CaptureRErrorFault].borrow(a).run(callback)
