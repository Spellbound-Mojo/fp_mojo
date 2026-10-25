# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOKwArityBox(Movable):
    var value: Int
def callback(var **options: Int) raises CaptureOKwArityFault -> Int:
    return 0
def main():
    var a=CaptureOKwArityBox(1)
    _ = Capture[CaptureOKwArityFault].take(a^).kwargs(extra=3).run(callback)
