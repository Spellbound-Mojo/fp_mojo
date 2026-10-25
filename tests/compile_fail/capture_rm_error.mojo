# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRmErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmErrorBox(Movable):
    var value: Int
def callback(a: CaptureRmErrorBox, mut b: CaptureRmErrorBox) raises CaptureRmErrorOther -> Int:
    return 0
def main():
    var a=CaptureRmErrorBox(1)
    var b=CaptureRmErrorBox(2)
    _ = Capture[CaptureRmErrorFault].borrow(a).mutable(b).run(callback)
