# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRrKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrKwArityBox(Movable):
    var value: Int
def callback(a: CaptureRrKwArityBox, /, var **options: Int) raises CaptureRrKwArityFault -> Int:
    return 0
def main():
    var a=CaptureRrKwArityBox(1)
    var b=CaptureRrKwArityBox(2)
    _ = Capture[CaptureRrKwArityFault].borrow(a).borrow(b).kwargs(extra=3).run(callback)
