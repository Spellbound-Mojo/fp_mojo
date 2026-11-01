# error: no matching
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextCapturePureMutPilotFault(Movable):
    var code: Int
def bad(mut value: Int) -> Int: return 1
def main():
    _ = Capture[Never]().run(bad)
