# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOmKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmKwErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOmKwErrorBox, mut b: CaptureOmKwErrorBox, /, var **options: Int) raises CaptureOmKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureOmKwErrorBox(1)
    var b=CaptureOmKwErrorBox(2)
    _ = Capture[CaptureOmKwErrorFault].take(a^).mutable(b).kwargs(extra=3).run(callback)
