# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMoArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoArityBox(Movable):
    var value: Int
def callback(mut a: CaptureMoArityBox) raises CaptureMoArityFault -> Int:
    return 0
def main():
    var a=CaptureMoArityBox(1)
    var b=CaptureMoArityBox(2)
    _ = Capture[CaptureMoArityFault].mutable(a).take(b^).run(callback)
