# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRrErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrErrorBox(Movable):
    var value: Int
def callback(a: CaptureRrErrorBox, b: CaptureRrErrorBox) raises CaptureRrErrorOther -> Int:
    return 0
def main():
    var a=CaptureRrErrorBox(1)
    var b=CaptureRrErrorBox(2)
    _ = Capture[CaptureRrErrorFault].borrow(a).borrow(b).run(callback)
