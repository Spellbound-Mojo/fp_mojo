# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOrKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrKwErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOrKwErrorBox, b: CaptureOrKwErrorBox, /, var **options: Int) raises CaptureOrKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureOrKwErrorBox(1)
    var b=CaptureOrKwErrorBox(2)
    _ = Capture[CaptureOrKwErrorFault].take(a^).borrow(b).kwargs(extra=3).run(callback)
