# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMrConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMrConventionBox, b: CaptureMrConventionBox) raises CaptureMrConventionFault -> Int:
    return 0
def main():
    var a=CaptureMrConventionBox(1)
    var b=CaptureMrConventionBox(2)
    _ = Capture[CaptureMrConventionFault].mutable(a).borrow(b).run(callback)
