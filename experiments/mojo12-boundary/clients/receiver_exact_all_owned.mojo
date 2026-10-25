from fp._binding_owned import Capture
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
    var a = Counter(0, drops)
    def mutate(mut value: Int) {var a^} -> Int:
        a.count += 1
        value += a.count
        return a.count
    var b = Counter(0, drops)
    def consume(var text: String) raises Fault {var b^} -> Int:
        b.count += 1
        if text.byte_length() == 0: raise Fault(b.count)
        return b.count
    var c = Counter(0, drops)
    def mixed(mut value: Int, var text: String) raises Fault {var c^} -> Int:
        c.count += 1
        value += text.byte_length()
        if text.byte_length() == 0: raise Fault(c.count)
        return c.count
    var d = Counter(0, drops)
    def keyword(mut value: Int, var text: String, /, var **options: Int) raises Fault {var d^} -> Int:
        d.count += 1
        value += text.byte_length()
        for option in options.items(): value += option.value
        if text.byte_length() == 0: raise Fault(d.count)
        return d.count
    var state = 0
    var am = Capture[Fault].mutating(mutate^)
    var ac = Capture[Fault].consuming(consume^)
    var ax = Capture[Fault].mut_owned(mixed^)
    var ak = Capture[Fault].mut_owned_kwargs(keyword^)
    for n in range(1, 4):
        assert_equal(am.run(state)._ok().value, n)
        assert_equal(ac.run(String("a"))._ok().value, n)
        assert_equal(ax.run(state, String("a"))._ok().value, n)
        assert_equal(ak.run(state, String("a"), extra=1)._ok().value, n)
    assert_equal(ac.run(String())._err().value.code, 4)
    assert_equal(ax.run(state, String())._err().value.code, 4)
    assert_equal(ak.run(state, String())._err().value.code, 4)
    assert_equal(state, 15)
    assert_equal(drops[], 0)
    _ = am^
    _ = ac^
    _ = ax^
    _ = ak^
def main() raises:
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 4)
