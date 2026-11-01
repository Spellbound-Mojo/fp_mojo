# error: no matching
from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
def bad(value: String) raises SliceFault -> Bool: return True
def main():
    _ = piped(List[Int]([1])).raising[SliceFault]().filter(bad)
