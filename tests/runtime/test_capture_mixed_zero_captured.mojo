from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMixedZeroCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMixedZeroCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar() {mut calls} -> Int:
        calls += 1
        var total = 0
        return total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 0)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar() {mut calls}:
        calls += 1
        var total = 0
        _ = total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar() raises Never {mut calls} -> Int:
        calls += 1
        var total = 0
        return total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 0)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar() raises Never {mut calls}:
        calls += 1
        var total = 0
        _ = total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar() raises CaptureMixedZeroCapturedFault {mut calls} -> Int:
        calls += 1
        var total = 0
        raise CaptureMixedZeroCapturedFault(total)
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMixedZeroCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 0)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar() raises CaptureMixedZeroCapturedFault {mut calls}:
        calls += 1
        var total = 0
        raise CaptureMixedZeroCapturedFault(total)
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedZeroCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 0)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box() {mut calls} -> Int:
        calls += 1
        var total = 0
        return total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 0)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box() {mut calls}:
        calls += 1
        var total = 0
        _ = total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box() raises Never {mut calls} -> Int:
        calls += 1
        var total = 0
        return total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 0)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box() raises Never {mut calls}:
        calls += 1
        var total = 0
        _ = total
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box() raises CaptureMixedZeroCapturedFault {mut calls} -> Int:
        calls += 1
        var total = 0
        raise CaptureMixedZeroCapturedFault(total)
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMixedZeroCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 0)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box() raises CaptureMixedZeroCapturedFault {mut calls}:
        calls += 1
        var total = 0
        raise CaptureMixedZeroCapturedFault(total)
    var result = Capture[CaptureMixedZeroCapturedFault]().run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedZeroCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 0)
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
