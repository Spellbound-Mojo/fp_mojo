from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(mut a: Int) {mut calls} -> Int:
        calls += 1
        a += 10
        var total = a
        return total
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 11)
    assert_equal(a, 11)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(mut a: Int) {mut calls}:
        calls += 1
        a += 10
        var total = a
        _ = total
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(mut a: Int) raises Never {mut calls} -> Int:
        calls += 1
        a += 10
        var total = a
        return total
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 11)
    assert_equal(a, 11)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(mut a: Int) raises Never {mut calls}:
        calls += 1
        a += 10
        var total = a
        _ = total
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(mut a: Int) raises CaptureMCapturedFault {mut calls} -> Int:
        calls += 1
        a += 10
        var total = a
        raise CaptureMCapturedFault(total)
    var a = 1
    var result = Capture[CaptureMCapturedFault].mutable(a).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 11)
    assert_equal(a, 11)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(mut a: Int) raises CaptureMCapturedFault {mut calls}:
        calls += 1
        a += 10
        var total = a
        raise CaptureMCapturedFault(total)
    var a = 1
    var result = Capture[CaptureMCapturedFault].mutable(a).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 11)
    assert_equal(a, 11)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(mut a: CaptureMCapturedBox) {mut calls} -> Int:
        calls += 1
        a.value += 10
        var total = a.value
        return total
    var a = CaptureMCapturedBox(1)
    var result = Capture[Never].mutable(a).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 11)
    assert_equal(a.value, 11)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(mut a: CaptureMCapturedBox) {mut calls}:
        calls += 1
        a.value += 10
        var total = a.value
        _ = total
    var a = CaptureMCapturedBox(1)
    var result = Capture[Never].mutable(a).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(mut a: CaptureMCapturedBox) raises Never {mut calls} -> Int:
        calls += 1
        a.value += 10
        var total = a.value
        return total
    var a = CaptureMCapturedBox(1)
    var result = Capture[Never].mutable(a).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 11)
    assert_equal(a.value, 11)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(mut a: CaptureMCapturedBox) raises Never {mut calls}:
        calls += 1
        a.value += 10
        var total = a.value
        _ = total
    var a = CaptureMCapturedBox(1)
    var result = Capture[Never].mutable(a).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(mut a: CaptureMCapturedBox) raises CaptureMCapturedFault {mut calls} -> Int:
        calls += 1
        a.value += 10
        var total = a.value
        raise CaptureMCapturedFault(total)
    var a = CaptureMCapturedBox(1)
    var result = Capture[CaptureMCapturedFault].mutable(a).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 11)
    assert_equal(a.value, 11)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(mut a: CaptureMCapturedBox) raises CaptureMCapturedFault {mut calls}:
        calls += 1
        a.value += 10
        var total = a.value
        raise CaptureMCapturedFault(total)
    var a = CaptureMCapturedBox(1)
    var result = Capture[CaptureMCapturedFault].mutable(a).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 11)
    assert_equal(a.value, 11)
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
