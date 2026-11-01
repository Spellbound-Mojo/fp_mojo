from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMixedOrCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMixedOrCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(var a: Int, b: Int) {mut calls} -> Int:
        calls += 1
        var total = a + b
        return total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrCapturedFault].take(a).borrow(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
    assert_equal(b, 2)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(var a: Int, b: Int) {mut calls}:
        calls += 1
        var total = a + b
        _ = total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrCapturedFault].take(a).borrow(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b, 2)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(var a: Int, b: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a + b
        return total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrCapturedFault].take(a).borrow(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
    assert_equal(b, 2)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(var a: Int, b: Int) raises Never {mut calls}:
        calls += 1
        var total = a + b
        _ = total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrCapturedFault].take(a).borrow(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b, 2)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(var a: Int, b: Int) raises CaptureMixedOrCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a + b
        raise CaptureMixedOrCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrCapturedFault].take(a).borrow(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMixedOrCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
    assert_equal(b, 2)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(var a: Int, b: Int) raises CaptureMixedOrCapturedFault {mut calls}:
        calls += 1
        var total = a + b
        raise CaptureMixedOrCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrCapturedFault].take(a).borrow(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedOrCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
    assert_equal(b, 2)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(var a: CaptureMixedOrCapturedBox, b: CaptureMixedOrCapturedBox) {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        return total
    var a = CaptureMixedOrCapturedBox(1)
    var b = CaptureMixedOrCapturedBox(2)
    var result = Capture[CaptureMixedOrCapturedFault].take(a^).borrow(b).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
    assert_equal(b.value, 2)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(var a: CaptureMixedOrCapturedBox, b: CaptureMixedOrCapturedBox) {mut calls}:
        calls += 1
        var total = a.value + b.value
        _ = total
    var a = CaptureMixedOrCapturedBox(1)
    var b = CaptureMixedOrCapturedBox(2)
    var result = Capture[CaptureMixedOrCapturedFault].take(a^).borrow(b).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(var a: CaptureMixedOrCapturedBox, b: CaptureMixedOrCapturedBox) raises Never {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        return total
    var a = CaptureMixedOrCapturedBox(1)
    var b = CaptureMixedOrCapturedBox(2)
    var result = Capture[CaptureMixedOrCapturedFault].take(a^).borrow(b).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
    assert_equal(b.value, 2)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(var a: CaptureMixedOrCapturedBox, b: CaptureMixedOrCapturedBox) raises Never {mut calls}:
        calls += 1
        var total = a.value + b.value
        _ = total
    var a = CaptureMixedOrCapturedBox(1)
    var b = CaptureMixedOrCapturedBox(2)
    var result = Capture[CaptureMixedOrCapturedFault].take(a^).borrow(b).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(var a: CaptureMixedOrCapturedBox, b: CaptureMixedOrCapturedBox) raises CaptureMixedOrCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        raise CaptureMixedOrCapturedFault(total)
    var a = CaptureMixedOrCapturedBox(1)
    var b = CaptureMixedOrCapturedBox(2)
    var result = Capture[CaptureMixedOrCapturedFault].take(a^).borrow(b).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMixedOrCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
    assert_equal(b.value, 2)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(var a: CaptureMixedOrCapturedBox, b: CaptureMixedOrCapturedBox) raises CaptureMixedOrCapturedFault {mut calls}:
        calls += 1
        var total = a.value + b.value
        raise CaptureMixedOrCapturedFault(total)
    var a = CaptureMixedOrCapturedBox(1)
    var b = CaptureMixedOrCapturedBox(2)
    var result = Capture[CaptureMixedOrCapturedFault].take(a^).borrow(b).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedOrCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
    assert_equal(b.value, 2)
def main() raises:
    check_pure_value_scalar()
    check_pure_void_scalar()
    check_never_value_scalar()
    check_never_void_scalar()
    check_error_value_scalar()
    check_error_void_scalar()
    check_pure_value_box()
    check_pure_void_box()
    check_never_value_box()
    check_never_void_box()
    check_error_value_box()
    check_error_void_box()
