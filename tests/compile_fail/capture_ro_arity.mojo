# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRoArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoArityBox(Movable):
    var value: Int
def callback(a: CaptureRoArityBox) raises CaptureRoArityFault -> Int:
    return 0
def main():
    var a=CaptureRoArityBox(1)
    var b=CaptureRoArityBox(2)
    _ = Capture[CaptureRoArityFault].borrow(a).take(b^).run(callback)
