# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMrArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrArityBox(Movable):
    var value: Int
def callback(mut a: CaptureMrArityBox) raises CaptureMrArityFault -> Int:
    return 0
def main():
    var a=CaptureMrArityBox(1)
    var b=CaptureMrArityBox(2)
    _ = Capture[CaptureMrArityFault].mutable(a).borrow(b).run(callback)
