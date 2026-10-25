# error: no matching
from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct PilotFault(Movable):
    var code: Int
def bad(mut value: Int) raises PilotFault -> Int: return 1
def main():
    _ = piped(List[Int]([1])).raising[PilotFault]().map(bad)
