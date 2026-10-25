# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureMoKwErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoKwErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoKwErrorBox(Movable):
    var value: Int
def callback(mut a: CaptureMoKwErrorBox, var b: CaptureMoKwErrorBox, /, var **options: Int) raises CaptureMoKwErrorOther -> Int:
    return 0
def main():
    var a=CaptureMoKwErrorBox(1)
    var b=CaptureMoKwErrorBox(2)
    _ = Capture[CaptureMoKwErrorFault].mutable(a).take(b^).kwargs(extra=3).run(callback)
