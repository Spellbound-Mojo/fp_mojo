from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
@fieldwise_init
struct SliceState(Movable):
    var count: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
def exercise(drops: ArcPointer[Int]) raises:
    var state = SliceState(0, drops)
    def transform(var value: Int) {var state^} -> Int:
        state.count += 1
        return state.count
    var output = piped(List[Int]([0, 0, 0])).map(transform).get()
    assert_equal(output, List[Int]([1, 2, 3]))
    assert_equal(transform(0), 4)
    assert_equal(drops[], 0)
    _ = transform^
def main() raises:
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 1)
