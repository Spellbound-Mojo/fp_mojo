# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMmKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmKwConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMmKwConventionBox, mut b: CaptureMmKwConventionBox, /, var **options: Int) raises CaptureMmKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureMmKwConventionBox(1)
    var b=CaptureMmKwConventionBox(2)
    _ = Capture[CaptureMmKwConventionFault].mutable(a).mutable(b).kwargs(extra=3).run(callback)
