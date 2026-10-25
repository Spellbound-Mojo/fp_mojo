# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMmArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmArityBox(Movable):
    var value: Int
def callback(mut a: CaptureMmArityBox) raises CaptureMmArityFault -> Int:
    return 0
def main():
    var a=CaptureMmArityBox(1)
    var b=CaptureMmArityBox(2)
    _ = Capture[CaptureMmArityFault].mutable(a).mutable(b).run(callback)
