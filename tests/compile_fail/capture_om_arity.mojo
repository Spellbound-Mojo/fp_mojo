# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOmArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmArityBox(Movable):
    var value: Int
def callback(var a: CaptureOmArityBox) raises CaptureOmArityFault -> Int:
    return 0
def main():
    var a=CaptureOmArityBox(1)
    var b=CaptureOmArityBox(2)
    _ = Capture[CaptureOmArityFault].take(a^).mutable(b).run(callback)
