# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMmErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMmErrorBox, mut b: CaptureMmErrorBox) raises CaptureMmErrorOther -> Int:
    return 0
def main():
    var a=CaptureMmErrorBox(1)
    var b=CaptureMmErrorBox(2)
    _ = Capture[CaptureMmErrorFault].mutable(a).mutable(b).run(callback)
