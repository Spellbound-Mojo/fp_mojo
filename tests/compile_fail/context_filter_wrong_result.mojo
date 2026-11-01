# error: no matching
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextFilterWrongResultSliceFault(Movable):
    var code: Int
def bad(value: Int) raises ContextFilterWrongResultSliceFault -> Int: return 1
def main():
    _ = piped(List[Int]([1])).raising[ContextFilterWrongResultSliceFault]().filter(bad)
