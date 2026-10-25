# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOrErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOrErrorBox, b: CaptureOrErrorBox) raises CaptureOrErrorOther -> Int:
    return 0
def main():
    var a=CaptureOrErrorBox(1)
    var b=CaptureOrErrorBox(2)
    _ = Capture[CaptureOrErrorFault].take(a^).borrow(b).run(callback)
