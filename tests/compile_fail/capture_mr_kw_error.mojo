# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMrKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMrKwErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMrKwErrorBox, b: CaptureMrKwErrorBox, /, var **options: Int) raises CaptureMrKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureMrKwErrorBox(1)
    var b=CaptureMrKwErrorBox(2)
    _ = Capture[CaptureMrKwErrorFault].mutable(a).borrow(b).kwargs(extra=3).run(callback)
