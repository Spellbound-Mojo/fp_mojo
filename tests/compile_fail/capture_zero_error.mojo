# error: no matching method
# error: cannot be converted
from fp.data import Capture
@fieldwise_init
struct CaptureZeroErrorFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroErrorOther(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroErrorBox(Movable):
    var value: Int
def callback() raises CaptureZeroErrorOther -> Int:
    return 0
def main():
    _ = Capture[CaptureZeroErrorFault]().run(callback)
