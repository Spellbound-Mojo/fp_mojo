# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMArityFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMArityOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMArityBox(Movable):
    var value: Int
def callback() raises CaptureMArityFault -> Int:
    return 0
def main():
    var a=CaptureMArityBox(1)
    _ = Capture[CaptureMArityFault].mutable(a).run(callback)
