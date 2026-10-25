# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureZeroArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroArityBox(Movable):
    var value: Int
def callback(var a: CaptureZeroArityBox) raises CaptureZeroArityFault -> Int:
    return 0
def main():
    _ = Capture[CaptureZeroArityFault]().run(callback)
