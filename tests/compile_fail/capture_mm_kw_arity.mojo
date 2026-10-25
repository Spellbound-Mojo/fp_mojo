# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMmKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmKwArityBox(Movable):
    var value: Int
def callback(mut a: CaptureMmKwArityBox, /, var **options: Int) raises CaptureMmKwArityFault -> Int:
    return 0
def main():
    var a=CaptureMmKwArityBox(1)
    var b=CaptureMmKwArityBox(2)
    _ = Capture[CaptureMmKwArityFault].mutable(a).mutable(b).kwargs(extra=3).run(callback)
