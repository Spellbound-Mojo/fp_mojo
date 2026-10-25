# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRmArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmArityBox(Movable):
    var value: Int
def callback(a: CaptureRmArityBox) raises CaptureRmArityFault -> Int:
    return 0
def main():
    var a=CaptureRmArityBox(1)
    var b=CaptureRmArityBox(2)
    _ = Capture[CaptureRmArityFault].borrow(a).mutable(b).run(callback)
