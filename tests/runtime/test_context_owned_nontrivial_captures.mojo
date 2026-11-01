from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextOwnedNontrivialCapturesSliceFault(Movable):
    var code: Int
@fieldwise_init
struct ContextOwnedNontrivialCapturesSliceState(Movable):
    var count: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
def exercise(drops: ArcPointer[Int]) raises:
    var state = ContextOwnedNontrivialCapturesSliceState(0, drops)
    def transform(var value: String) {var state^} -> String:
        state.count += 1
        return String(state.count)
    var output = piped(List[String](["a", "b", "c"])).map(transform).get()
    assert_equal(output, List[String](["1", "2", "3"]))
    assert_equal(transform(String("d")), "4")
    assert_equal(drops[], 0)
    _ = transform^
def main() raises:
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 1)
