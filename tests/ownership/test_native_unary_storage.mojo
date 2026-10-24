"""Stored native callbacks keep captures when borrowed and extracted."""
from fp.functions import as_unary
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct NativeUnaryStorageToken(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def exercise(drops: ArcPointer[Int]) raises:
    var token = NativeUnaryStorageToken(drops)
    var calls = 0
    def captured(var value: Int) {var token^, mut calls} -> Int:
        _ = token.drops[]
        calls += 1
        return value + calls
    var wrapped = as_unary(captured^)
    comptime assert not conforms_to(type_of(wrapped), Copyable)
    assert_equal(wrapped.call(10), 11)
    assert_equal(wrapped.function()(10), 12)
    var original = wrapped^.into_function()
    assert_equal(drops[], 0)
    assert_equal(original(10), 13)
    assert_equal(calls, 3)


def native_storage_increment(var value: Int) -> Int:
    return value + 1


def native_storage_checked(var value: Int) raises Int -> Int:
    if value < 0:
        raise value
    return value + 2


def plain_copies() raises:
    var original = as_unary(native_storage_increment)
    comptime assert conforms_to(type_of(original), ImplicitlyCopyable)
    var copied = original.copy()
    assert_equal(original.call(3), 4)
    assert_equal(copied.call(5), 6)
    var checked = as_unary(native_storage_checked)
    comptime assert conforms_to(type_of(checked), ImplicitlyCopyable)
    var checked_copy = checked.copy()
    var checked_value: Int
    try:
        checked_value = checked.call(3)
    except error:
        comptime assert type_of(error) == Int
        raise Error("unexpected callback error")
    assert_equal(checked_value, 5)
    var caught = False
    try:
        _ = checked_copy.call(-7)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, -7)
        caught = True
    assert_equal(caught, True)


def main() raises:
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 1)
    plain_copies()
