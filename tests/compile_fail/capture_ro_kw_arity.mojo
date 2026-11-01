# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRoKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoKwArityBox(Movable):
    var value: Int
def callback(a: CaptureRoKwArityBox, /, var **options: Int) raises CaptureRoKwArityFault -> Int:
    return 0
def main():
    var a=CaptureRoKwArityBox(1)
    var b=CaptureRoKwArityBox(2)
    _ = Capture[CaptureRoKwArityFault].borrow(a).take(b^).kwargs(extra=3).run(callback)
