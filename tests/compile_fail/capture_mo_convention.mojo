# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMoConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMoConventionBox, var b: CaptureMoConventionBox) raises CaptureMoConventionFault -> Int:
    return 0
def main():
    var a=CaptureMoConventionBox(1)
    var b=CaptureMoConventionBox(2)
    _ = Capture[CaptureMoConventionFault].mutable(a).take(b^).run(callback)
