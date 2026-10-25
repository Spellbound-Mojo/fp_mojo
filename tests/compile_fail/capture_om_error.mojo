# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOmErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmErrorBox(Movable):
    var value: Int
def callback(var a: CaptureOmErrorBox, mut b: CaptureOmErrorBox) raises CaptureOmErrorOther -> Int:
    return 0
def main():
    var a=CaptureOmErrorBox(1)
    var b=CaptureOmErrorBox(2)
    _ = Capture[CaptureOmErrorFault].take(a^).mutable(b).run(callback)
