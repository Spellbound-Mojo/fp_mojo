# error: no matching
from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct PilotFault(Movable):
    var code: Int
def bad(value: Int, extra: Int) raises PilotFault -> Int: return 1
def main():
    _ = Capture[PilotFault].run(bad)
