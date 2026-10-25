from fp._binding_architecture import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Fault(Movable):
    var code: Int
@fieldwise_init
struct Counter(Movable):
    var count: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def exercise(drops: ArcPointer[Int]) raises:
    var counter = Counter(0, drops)
    def callback(var text: String) {var counter^} -> Int:
        counter.count += 1
        _ = text^
        return counter.count
    var adapter = Capture[Fault].consuming(callback)
    for n in range(1, 4):
        assert_equal(adapter.run(String("a"))._ok().value, n)
    assert_equal(adapter.run(String("a"))._ok().value, 4)
    assert_equal(drops[], 0)
    _ = callback^
def main() raises:
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 1)
