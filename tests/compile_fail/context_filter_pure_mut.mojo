# error: no matching
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextFilterPureMutPilotFault(Movable):
    var code: Int
def bad(mut value: Int) -> Bool: return True
def main():
    _ = piped(List[Int]([1])).filter(bad)
