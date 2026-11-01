# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOoKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoKwArityBox(Movable):
    var value: Int
def callback(var a: CaptureOoKwArityBox, /, var **options: Int) raises CaptureOoKwArityFault -> Int:
    return 0
def main():
    var a=CaptureOoKwArityBox(1)
    var b=CaptureOoKwArityBox(2)
    _ = Capture[CaptureOoKwArityFault].take(a^).take(b^).kwargs(extra=3).run(callback)
