# error: no matching
from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextFilterWrongInputSliceFault(Movable):
    var code: Int
def bad(value: String) raises ContextFilterWrongInputSliceFault -> Bool: return True
def main():
    _ = piped(List[Int]([1])).raising[ContextFilterWrongInputSliceFault]().filter(bad)
