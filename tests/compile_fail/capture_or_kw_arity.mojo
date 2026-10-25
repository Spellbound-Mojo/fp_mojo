# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOrKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrKwArityBox(Movable):
    var value: Int
def callback(var a: CaptureOrKwArityBox, /, var **options: Int) raises CaptureOrKwArityFault -> Int:
    return 0
def main():
    var a=CaptureOrKwArityBox(1)
    var b=CaptureOrKwArityBox(2)
    _ = Capture[CaptureOrKwArityFault].take(a^).borrow(b).kwargs(extra=3).run(callback)
