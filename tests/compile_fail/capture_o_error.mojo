# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOErrorBox) raises CaptureOErrorOther -> Int:
    return 0
def main():
    var a=CaptureOErrorBox(1)
    _ = Capture[CaptureOErrorFault].take(a^).run(callback)
