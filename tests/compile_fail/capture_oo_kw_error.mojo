# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOoKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoKwErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOoKwErrorBox, var b: CaptureOoKwErrorBox, /, var **options: Int) raises CaptureOoKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureOoKwErrorBox(1)
    var b=CaptureOoKwErrorBox(2)
    _ = Capture[CaptureOoKwErrorFault].take(a^).take(b^).kwargs(extra=3).run(callback)
