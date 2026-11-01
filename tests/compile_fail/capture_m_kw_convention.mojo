# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMKwConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMKwConventionBox, /, var **options: Int) raises CaptureMKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureMKwConventionBox(1)
    _ = Capture[CaptureMKwConventionFault].mutable(a).kwargs(extra=3).run(callback)
