# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMrErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMrErrorBox, b: CaptureMrErrorBox) raises CaptureMrErrorOther -> Int:
    return 0
def main():
    var a=CaptureMrErrorBox(1)
    var b=CaptureMrErrorBox(2)
    _ = Capture[CaptureMrErrorFault].mutable(a).borrow(b).run(callback)
