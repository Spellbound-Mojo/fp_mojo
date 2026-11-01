# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRArityBox(Movable):
    var value: Int
def callback() raises CaptureRArityFault -> Int:
    return 0
def main():
    var a=CaptureRArityBox(1)
    _ = Capture[CaptureRArityFault].borrow(a).run(callback)
