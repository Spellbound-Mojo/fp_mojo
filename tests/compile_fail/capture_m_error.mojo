# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMErrorBox) raises CaptureMErrorOther -> Int:
    return 0
def main():
    var a=CaptureMErrorBox(1)
    _ = Capture[CaptureMErrorFault].mutable(a).run(callback)
