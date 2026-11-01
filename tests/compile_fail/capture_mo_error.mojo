# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMoErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMoErrorBox, var b: CaptureMoErrorBox) raises CaptureMoErrorOther -> Int:
    return 0
def main():
    var a=CaptureMoErrorBox(1)
    var b=CaptureMoErrorBox(2)
    _ = Capture[CaptureMoErrorFault].mutable(a).take(b^).run(callback)
