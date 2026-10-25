# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOoArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoArityBox(Movable):
    var value: Int
def callback(var a: CaptureOoArityBox) raises CaptureOoArityFault -> Int:
    return 0
def main():
    var a=CaptureOoArityBox(1)
    var b=CaptureOoArityBox(2)
    _ = Capture[CaptureOoArityFault].take(a^).take(b^).run(callback)
