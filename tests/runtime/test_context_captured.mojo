from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextCapturedPilotFault(Movable):
    var code: Int
def main() raises:
    var count = 0
    def select(value: Int) {mut count} -> Bool:
        count += 1
        return value > 1
    def transform(var value: Int) {mut count} -> Int:
        count += value
        return value * 2
    var output = piped(List[Int]([1, 2, 3])).filter(select).map(transform).get()
    assert_equal(output, List[Int]([4, 6]))
    assert_equal(count, 8)
    def source() {mut count} -> Int:
        count += 1
        return count
    assert_equal(Capture[Never]().run(source)._ok().value, 9)
