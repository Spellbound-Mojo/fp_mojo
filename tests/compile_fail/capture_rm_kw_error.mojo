# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRmKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmKwErrorBox(Movable):
    var value: Int
def callback(a: CaptureRmKwErrorBox, mut b: CaptureRmKwErrorBox, /, var **options: Int) raises CaptureRmKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureRmKwErrorBox(1)
    var b=CaptureRmKwErrorBox(2)
    _ = Capture[CaptureRmKwErrorFault].borrow(a).mutable(b).kwargs(extra=3).run(callback)
