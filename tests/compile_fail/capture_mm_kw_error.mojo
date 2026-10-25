# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMmKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmKwErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMmKwErrorBox, mut b: CaptureMmKwErrorBox, /, var **options: Int) raises CaptureMmKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureMmKwErrorBox(1)
    var b=CaptureMmKwErrorBox(2)
    _ = Capture[CaptureMmKwErrorFault].mutable(a).mutable(b).kwargs(extra=3).run(callback)
