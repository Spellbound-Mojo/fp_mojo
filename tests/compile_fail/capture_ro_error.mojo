# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRoErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoErrorBox(Movable):
    var value: Int
def callback(a: CaptureRoErrorBox, var b: CaptureRoErrorBox) raises CaptureRoErrorOther -> Int:
    return 0
def main():
    var a=CaptureRoErrorBox(1)
    var b=CaptureRoErrorBox(2)
    _ = Capture[CaptureRoErrorFault].borrow(a).take(b^).run(callback)
