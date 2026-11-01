# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRmKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmKwArityBox(Movable):
    var value: Int
def callback(a: CaptureRmKwArityBox, /, var **options: Int) raises CaptureRmKwArityFault -> Int:
    return 0
def main():
    var a=CaptureRmKwArityBox(1)
    var b=CaptureRmKwArityBox(2)
    _ = Capture[CaptureRmKwArityFault].borrow(a).mutable(b).kwargs(extra=3).run(callback)
