# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMConventionBox) raises CaptureMConventionFault -> Int:
    return 0
def main():
    var a=CaptureMConventionBox(1)
    _ = Capture[CaptureMConventionFault].mutable(a).run(callback)
