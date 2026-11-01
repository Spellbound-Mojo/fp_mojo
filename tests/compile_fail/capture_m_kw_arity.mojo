# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMKwArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMKwArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMKwArityBox(Movable):
    var value: Int
def callback(var **options: Int) raises CaptureMKwArityFault -> Int:
    return 0
def main():
    var a=CaptureMKwArityBox(1)
    _ = Capture[CaptureMKwArityFault].mutable(a).kwargs(extra=3).run(callback)
