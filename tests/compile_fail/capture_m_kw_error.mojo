# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMKwErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMKwErrorBox, /, var **options: Int) raises CaptureMKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureMKwErrorBox(1)
    _ = Capture[CaptureMKwErrorFault].mutable(a).kwargs(extra=3).run(callback)
