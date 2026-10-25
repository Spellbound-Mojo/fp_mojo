from fp._binding_architecture import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Fault(Movable):
    var code: Int

@fieldwise_init
struct Owner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
def consume(var value: Owner) raises Fault -> Owner:
    if value.value < 0: raise Fault(value.value)
    return value^
def mixed(mut state: Int, var value: Owner) raises Fault -> Int:
    state += value.value
    if value.value < 0: raise Fault(state)
    return state
def keyword(mut state: Int, var value: Owner, /, var **options: Owner) raises Fault -> Int:
    state += value.value
    try:
        for key in options.keys(): state += options[key].value
    except _:
        raise Fault(-999)
    raise Fault(state)
def success(drops: ArcPointer[Int]) raises:
    var result = Capture[Fault].consuming(consume).run(Owner(3, drops))
    assert_equal(result._ok().value.value, 3)
    assert_equal(drops[], 0)
    _ = result^
def main() raises:
    var drops = ArcPointer(0)
    success(drops)
    assert_equal(drops[], 1)
    assert_equal(Capture[Fault].consuming(consume).run(Owner(-2, drops))._err().value.code, -2)
    assert_equal(drops[], 2)
    var state = 5
    assert_equal(Capture[Fault].mut_owned(mixed).run(state, Owner(3, drops))._ok().value, 8)
    assert_equal(drops[], 3)
    assert_equal(Capture[Fault].mut_owned(mixed).run(state, Owner(-4, drops))._err().value.code, 4)
    assert_equal(drops[], 4)
    assert_equal(Capture[Fault].mut_owned_kwargs(keyword).run(state, Owner(1, drops), extra=Owner(2, drops))._err().value.code, 7)
    assert_equal(drops[], 6)
    assert_equal(state, 7)
