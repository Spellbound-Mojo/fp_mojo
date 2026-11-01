# error: no matching
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextCaptureRaisingMutPilotFault(Movable):
    var code: Int
def bad(mut value: Int) raises ContextCaptureRaisingMutPilotFault -> Int: return 1
def main():
    _ = Capture[ContextCaptureRaisingMutPilotFault]().run(bad)
