from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(a: Int) {mut calls} -> Int:
        calls += 1
        var total = a
        return total
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
    assert_equal(a, 1)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(a: Int) {mut calls}:
        calls += 1
        var total = a
        _ = total
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(a: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a
        return total
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
    assert_equal(a, 1)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(a: Int) raises Never {mut calls}:
        calls += 1
        var total = a
        _ = total
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(a: Int) raises CaptureRCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a
        raise CaptureRCapturedFault(total)
    var a = 1
    var result = Capture[CaptureRCapturedFault].borrow(a).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
    assert_equal(a, 1)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(a: Int) raises CaptureRCapturedFault {mut calls}:
        calls += 1
        var total = a
        raise CaptureRCapturedFault(total)
    var a = 1
    var result = Capture[CaptureRCapturedFault].borrow(a).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
    assert_equal(a, 1)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(a: CaptureRCapturedBox) {mut calls} -> Int:
        calls += 1
        var total = a.value
        return total
    var a = CaptureRCapturedBox(1)
    var result = Capture[Never].borrow(a).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
    assert_equal(a.value, 1)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(a: CaptureRCapturedBox) {mut calls}:
        calls += 1
        var total = a.value
        _ = total
    var a = CaptureRCapturedBox(1)
    var result = Capture[Never].borrow(a).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(a: CaptureRCapturedBox) raises Never {mut calls} -> Int:
        calls += 1
        var total = a.value
        return total
    var a = CaptureRCapturedBox(1)
    var result = Capture[Never].borrow(a).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
    assert_equal(a.value, 1)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(a: CaptureRCapturedBox) raises Never {mut calls}:
        calls += 1
        var total = a.value
        _ = total
    var a = CaptureRCapturedBox(1)
    var result = Capture[Never].borrow(a).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(a: CaptureRCapturedBox) raises CaptureRCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a.value
        raise CaptureRCapturedFault(total)
    var a = CaptureRCapturedBox(1)
    var result = Capture[CaptureRCapturedFault].borrow(a).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
    assert_equal(a.value, 1)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(a: CaptureRCapturedBox) raises CaptureRCapturedFault {mut calls}:
        calls += 1
        var total = a.value
        raise CaptureRCapturedFault(total)
    var a = CaptureRCapturedBox(1)
    var result = Capture[CaptureRCapturedFault].borrow(a).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
    assert_equal(a.value, 1)
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
