# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureRKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureRKwArityBox(Movable):
    var value: Int
def callback(var **options: Int) raises CaptureRKwArityFault -> Int:
    return 0
def main():
    var a=CaptureRKwArityBox(1)
    _ = Capture[CaptureRKwArityFault].borrow(a).kwargs(extra=3).run(callback)
