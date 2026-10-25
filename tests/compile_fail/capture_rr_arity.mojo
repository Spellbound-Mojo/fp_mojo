# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRrArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrArityBox(Movable):
    var value: Int
def callback(a: CaptureRrArityBox) raises CaptureRrArityFault -> Int:
    return 0
def main():
    var a=CaptureRrArityBox(1)
    var b=CaptureRrArityBox(2)
    _ = Capture[CaptureRrArityFault].borrow(a).borrow(b).run(callback)
