# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureZeroKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroKwArityBox(Movable):
    var value: Int
def callback(var a: CaptureZeroKwArityBox, /, var **options: Int) raises CaptureZeroKwArityFault -> Int:
    return 0
def main():
    _ = Capture[CaptureZeroKwArityFault].kwargs(extra=3).run(callback)
