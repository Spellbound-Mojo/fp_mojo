from fp.data import Capture, Result
from std.memory import ArcPointer
from std.collections import StringDict
from std.testing import assert_equal

@fieldwise_init
struct Fault(Movable):
    var code: Int

@fieldwise_init
struct Owner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def callback(mut state: Int, var value: Owner, /, var **kwargs: Owner) raises Fault -> Owner:
    state += value.value
    try:
        if len(kwargs):
            state += kwargs["extra"].value + kwargs["bonus"].value
    except _:
        raise Fault(-999)
    if value.value < 0:
        raise Fault(state)
    return value^

def update(mut state: Owner, var value: Int) raises Fault -> Int:
    state.value += value
    if value < 0:
        raise Fault(state.value)
    return state.value

def span[T: Copyable & Deinitable](mut state: T, var fail: Bool) raises T -> T:
    if fail:
        raise state.copy()
    return state.copy()

def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(mut View, var Bool) raises View thin -> View = span[View]
    var adapter = Capture[View]().stateful(pointer, view)
    var success = adapter.run(False)
    comptime assert type_of(success) == Result[View, View]
    assert_equal(Pointer(to=success._ok().value[0]) == Pointer(to=owner[0]), True)
    var error = adapter.run(True)
    assert_equal(Pointer(to=error._err().value[1]) == Pointer(to=owner[1]), True)
    var returned = adapter^.into_state()
    assert_equal(Pointer(to=returned[0]) == Pointer(to=owner[0]), True)

def main() raises:
    var drops = ArcPointer(0)
    var state = 0
    var pointer: def(mut Int, var Owner, /, var **kwargs: Owner) raises Fault thin -> Owner = callback
    var pending = Capture[Fault].mutable(state).take(Owner(2, drops)).kwargs(extra=Owner(3, drops), bonus=Owner(4, drops))
    assert_equal(state, 0)
    assert_equal(drops[], 0)
    var moved = pending^
    var result = moved^.run(pointer)
    assert_equal(result._ok().value.value, 2)
    assert_equal(state, 9)
    assert_equal(drops[], 2)
    _ = result^
    assert_equal(drops[], 3)
    var error = Capture[Fault].mutable(state).take(Owner(-2, drops)).kwargs(extra=Owner(3, drops), bonus=Owner(4, drops)).run(pointer)
    assert_equal(error._err().value.code, 14)
    assert_equal(drops[], 6)
    var unused = Capture[Fault].mutable(state).take(Owner(2, drops)).kwargs(extra=Owner(3, drops), bonus=Owner(4, drops))
    _ = unused^
    assert_equal(drops[], 9)
    assert_equal(state, 14)
    # A typed empty dictionary retains keyword inference without creating owners.
    var empty: StringDict[Owner] = {}
    var last = Capture[Fault].mutable(state).take(Owner(1, drops)).kwargs(**empty^).run(pointer)
    assert_equal(last._ok().value.value, 1)
    _ = last^
    assert_equal(drops[], 10)

    var function: def(mut Owner, var Int) raises Fault thin -> Int = update
    var adapter = Capture[Fault]().stateful(function, Owner(1, drops))
    assert_equal(adapter.run(2)._ok().value, 3)
    assert_equal(adapter.run(-1)._err().value.code, 2)
    assert_equal(adapter.state().value, 2)
    assert_equal(drops[], 10)
    var owned = adapter^.into_state()
    assert_equal(owned.value, 2)
    _ = owned^
    assert_equal(drops[], 11)
    var abandoned = Capture[Fault]().stateful(function, Owner(5, drops))
    _ = abandoned^
    assert_equal(drops[], 12)
    var owner: List[Int] = [3, 7]
    origins(owner)
