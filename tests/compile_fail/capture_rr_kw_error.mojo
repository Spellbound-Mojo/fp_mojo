# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRrKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrKwErrorBox(Movable):
    var value: Int
def callback(a: CaptureRrKwErrorBox, b: CaptureRrKwErrorBox, /, var **options: Int) raises CaptureRrKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureRrKwErrorBox(1)
    var b=CaptureRrKwErrorBox(2)
    _ = Capture[CaptureRrKwErrorFault].borrow(a).borrow(b).kwargs(extra=3).run(callback)
