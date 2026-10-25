# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMoKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoKwConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMoKwConventionBox, var b: CaptureMoKwConventionBox, /, var **options: Int) raises CaptureMoKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureMoKwConventionBox(1)
    var b=CaptureMoKwConventionBox(2)
    _ = Capture[CaptureMoKwConventionFault].mutable(a).take(b^).kwargs(extra=3).run(callback)
