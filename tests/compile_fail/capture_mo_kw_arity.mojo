# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMoKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoKwArityBox(Movable):
    var value: Int
def callback(mut a: CaptureMoKwArityBox, /, var **options: Int) raises CaptureMoKwArityFault -> Int:
    return 0
def main():
    var a=CaptureMoKwArityBox(1)
    var b=CaptureMoKwArityBox(2)
    _ = Capture[CaptureMoKwArityFault].mutable(a).take(b^).kwargs(extra=3).run(callback)
