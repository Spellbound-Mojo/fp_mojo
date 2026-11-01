# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOmKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmKwArityBox(Movable):
    var value: Int
def callback(var a: CaptureOmKwArityBox, /, var **options: Int) raises CaptureOmKwArityFault -> Int:
    return 0
def main():
    var a=CaptureOmKwArityBox(1)
    var b=CaptureOmKwArityBox(2)
    _ = Capture[CaptureOmKwArityFault].take(a^).mutable(b).kwargs(extra=3).run(callback)
