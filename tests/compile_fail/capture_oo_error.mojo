# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOoErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOoErrorBox, var b: CaptureOoErrorBox) raises CaptureOoErrorOther -> Int:
    return 0
def main():
    var a=CaptureOoErrorBox(1)
    var b=CaptureOoErrorBox(2)
    _ = Capture[CaptureOoErrorFault].take(a^).take(b^).run(callback)
