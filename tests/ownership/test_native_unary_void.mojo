"""Stored no-value callbacks retain effects, captures, moves and copyability."""
from fp.functions import as_unary
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct VoidToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct VoidFailure(Movable):
    var code: Int

def pure(var value: VoidToken):
    _ = value.value

def never(var value: VoidToken) raises Never:
    _ = value.value

def raising(var value: VoidToken) raises VoidFailure:
    if value.value < 0: raise VoidFailure(value.value)

def explicit_none(var value: Int) -> NoneType:
    return None

def pure_register(var value: Int):
    _ = value

def never_register(var value: Int) raises Never:
    _ = value

def raising_register(var value: Int) raises VoidFailure:
    raise VoidFailure(value)

def captures(drops: ArcPointer[Int]) raises:
    var calls = 0
    var owner = VoidToken(10, drops)
    def captured(var value: VoidToken) {var owner^, mut calls}:
        calls += value.value + owner.value
    var callback = as_unary(captured^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    callback.call(VoidToken(1, drops))
    callback(VoidToken(2, drops))
    callback.function()(VoidToken(3, drops))
    var original = callback^.into_function()
    original(VoidToken(4, drops))
    assert_equal(calls, 50)
    var owner2 = VoidToken(20, drops)
    def captured_never(var value: VoidToken) raises Never {var owner2^, mut calls}:
        calls += value.value + owner2.value
    var second = as_unary(captured_never^)
    second.call(VoidToken(5, drops))
    second.call(VoidToken(6, drops))
    assert_equal(calls, 101)

def main() raises:
    var drops = ArcPointer(0)
    var pointer: def(var VoidToken) thin = pure
    var callback = as_unary(pointer)
    comptime assert conforms_to(type_of(callback), ImplicitlyCopyable)
    var copied = callback.copy()
    var result = callback.call(VoidToken(1, drops))
    comptime assert type_of(result) == type_of(None)
    _ = result
    copied(VoidToken(2, drops))
    var never_pointer: def(var VoidToken) raises Never thin = never
    as_unary(never_pointer).call(VoidToken(3, drops))
    var raising_pointer: def(var VoidToken) raises VoidFailure thin = raising
    var checked = as_unary(raising_pointer)
    comptime assert conforms_to(type_of(checked), ImplicitlyCopyable)
    var caught = 0
    try:
        checked.call(VoidToken(4, drops))
        checked.copy().call(VoidToken(-5, drops))
    except error:
        comptime assert type_of(error) == VoidFailure
        caught = error.code
    assert_equal(caught, -5)
    assert_equal(drops[], 5)
    _ = as_unary(explicit_none).call(0)
    var p: def(var Int) thin = pure_register
    var n: def(var Int) raises Never thin = never_register
    var r: def(var Int) raises VoidFailure thin = raising_register
    var void = as_unary(p)(1)
    comptime assert type_of(void) == type_of(None)
    _ = void
    as_unary(n)(2)
    try: as_unary(r)(-6)
    except error: caught = error.code
    assert_equal(caught, -6)
    captures(drops)
    assert_equal(drops[], 13)
