# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOKwErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOKwErrorBox, /, var **options: Int) raises CaptureOKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureOKwErrorBox(1)
    _ = Capture[CaptureOKwErrorFault].take(a^).kwargs(extra=3).run(callback)
