# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMrKwConventionFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrKwConventionOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrKwConventionBox(Movable):
    var value: Int
def callback(var a: CaptureMrKwConventionBox, b: CaptureMrKwConventionBox, /, var **options: Int) raises CaptureMrKwConventionFault -> Int:
    return 0
def main():
    var a=CaptureMrKwConventionBox(1)
    var b=CaptureMrKwConventionBox(2)
    _ = Capture[CaptureMrKwConventionFault].mutable(a).borrow(b).kwargs(extra=3).run(callback)
