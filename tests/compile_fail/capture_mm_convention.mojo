# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMmConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMmConventionBox, mut b: CaptureMmConventionBox) raises CaptureMmConventionFault -> Int:
    return 0
def main():
    var a=CaptureMmConventionBox(1)
    var b=CaptureMmConventionBox(2)
    _ = Capture[CaptureMmConventionFault].mutable(a).mutable(b).run(callback)
