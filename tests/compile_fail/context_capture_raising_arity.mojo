# error: no matching
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextCaptureRaisingArityPilotFault(Movable):
    var code: Int
def bad(value: Int, extra: Int) raises ContextCaptureRaisingArityPilotFault -> Int: return 1
def main():
    _ = Capture[ContextCaptureRaisingArityPilotFault]().run(bad)
