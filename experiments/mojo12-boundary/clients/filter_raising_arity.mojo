# error: no matching
from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct PilotFault(Movable):
    var code: Int
def bad(value: Int, extra: Int) raises PilotFault -> Bool: return True
def main():
    _ = piped(List[Int]([1])).raising[PilotFault]().filter(bad)
