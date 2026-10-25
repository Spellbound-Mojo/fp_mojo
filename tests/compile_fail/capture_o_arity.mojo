# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureOArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureOArityBox(Movable):
    var value: Int
def callback() raises CaptureOArityFault -> Int:
    return 0
def main():
    var a=CaptureOArityBox(1)
    _ = Capture[CaptureOArityFault].take(a^).run(callback)
