# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRKwErrorBox(Movable):
    var value: Int
def callback(a: CaptureRKwErrorBox, /, var **options: Int) raises CaptureRKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureRKwErrorBox(1)
    _ = Capture[CaptureRKwErrorFault].borrow(a).kwargs(extra=3).run(callback)
