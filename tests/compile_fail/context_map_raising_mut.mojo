# error: no matching
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextMapRaisingMutPilotFault(Movable):
    var code: Int
def bad(mut value: Int) raises ContextMapRaisingMutPilotFault -> Int: return 1
def main():
    _ = piped(List[Int]([1])).raising[ContextMapRaisingMutPilotFault]().map(bad)
