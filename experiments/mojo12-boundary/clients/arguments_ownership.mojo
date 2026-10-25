from fp._argument_staged import Capture
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Fault(Movable):
    var code: Int

@fieldwise_init
struct Owner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def callback(mut state: Int, var value: Owner, /, var **options: Owner) raises Fault -> Owner:
    state += value.value
    try:
        state += options["extra"].value + options["bonus"].value
    except _:
        raise Fault(-999)
    if value.value < 0: raise Fault(state)
    return value^

def main() raises:
    var drops = ArcPointer(0)
    var state = 0
    var pending = Capture[Fault].kwargs(state, Owner(2, drops), extra=Owner(3, drops), bonus=Owner(4, drops))
    assert_equal(drops[], 0)
    assert_equal(state, 0)
    var moved = pending^
    var result = moved^.run(callback)
    assert_equal(result._ok().value.value, 2)
    assert_equal(state, 9)
    assert_equal(drops[], 2)
    _ = result^
    assert_equal(drops[], 3)
    var error = Capture[Fault].kwargs(state, Owner(-2, drops), extra=Owner(3, drops), bonus=Owner(4, drops)).run(callback)
    assert_equal(error._err().value.code, 14)
    assert_equal(drops[], 6)
    var unused = Capture[Fault].kwargs(state, Owner(2, drops), extra=Owner(3, drops), bonus=Owner(4, drops))
    _ = unused^
    assert_equal(drops[], 9)
    assert_equal(state, 14)
