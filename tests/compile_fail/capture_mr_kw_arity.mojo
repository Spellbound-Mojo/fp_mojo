# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMrKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrKwArityBox(Movable):
    var value: Int
def callback(mut a: CaptureMrKwArityBox, /, var **options: Int) raises CaptureMrKwArityFault -> Int:
    return 0
def main():
    var a=CaptureMrKwArityBox(1)
    var b=CaptureMrKwArityBox(2)
    _ = Capture[CaptureMrKwArityFault].mutable(a).borrow(b).kwargs(extra=3).run(callback)
