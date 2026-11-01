from fp._binding_state import Capture
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
# Same update and error condition as the failing owned-capture control.
def callback(mut counter: Counter, var text: String) raises Fault -> Int:
    counter.count += 1
    if text.byte_length() == 0: raise Fault(counter.count)
    return counter.count
def exercise(drops: ArcPointer[Int]) raises:
    var adapter = Capture[Fault].stateful(callback, Counter(0, drops))
    for n in range(1,4):
        assert_equal(adapter.run(String("a"))._ok().value,n)
    assert_equal(adapter.run(String())._err().value.code,4)
    assert_equal(adapter.run(String("a"))._ok().value,5)
    assert_equal(adapter.state().count,5)
    assert_equal(drops[],0)
    var returned = adapter^.into_state()
    assert_equal(returned.count,5)
    assert_equal(drops[],0)
    _ = returned^
def main() raises:
    var drops=ArcPointer(0)
    exercise(drops)
    assert_equal(drops[],1)
