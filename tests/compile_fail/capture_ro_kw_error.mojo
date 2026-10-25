# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRoKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoKwErrorBox(Movable):
    var value: Int
def callback(a: CaptureRoKwErrorBox, var b: CaptureRoKwErrorBox, /, var **options: Int) raises CaptureRoKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureRoKwErrorBox(1)
    var b=CaptureRoKwErrorBox(2)
    _ = Capture[CaptureRoKwErrorFault].borrow(a).take(b^).kwargs(extra=3).run(callback)
