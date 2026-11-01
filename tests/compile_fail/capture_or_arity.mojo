# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOrArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrArityBox(Movable):
    var value: Int
def callback(var a: CaptureOrArityBox) raises CaptureOrArityFault -> Int:
    return 0
def main():
    var a=CaptureOrArityBox(1)
    var b=CaptureOrArityBox(2)
    _ = Capture[CaptureOrArityFault].take(a^).borrow(b).run(callback)
