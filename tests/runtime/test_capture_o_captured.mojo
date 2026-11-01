from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(var a: Int) {mut calls} -> Int:
        calls += 1
        var total = a
        return total
    var a = 1
    var result = Capture[Never].take(a).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(var a: Int) {mut calls}:
        calls += 1
        var total = a
        _ = total
    var a = 1
    var result = Capture[Never].take(a).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(var a: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a
        return total
    var a = 1
    var result = Capture[Never].take(a).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(var a: Int) raises Never {mut calls}:
        calls += 1
        var total = a
        _ = total
    var a = 1
    var result = Capture[Never].take(a).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(var a: Int) raises CaptureOCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a
        raise CaptureOCapturedFault(total)
    var a = 1
    var result = Capture[CaptureOCapturedFault].take(a).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(var a: Int) raises CaptureOCapturedFault {mut calls}:
        calls += 1
        var total = a
        raise CaptureOCapturedFault(total)
    var a = 1
    var result = Capture[CaptureOCapturedFault].take(a).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(var a: CaptureOCapturedBox) {mut calls} -> Int:
        calls += 1
        var total = a.value
        return total
    var a = CaptureOCapturedBox(1)
    var result = Capture[Never].take(a^).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(var a: CaptureOCapturedBox) {mut calls}:
        calls += 1
        var total = a.value
        _ = total
    var a = CaptureOCapturedBox(1)
    var result = Capture[Never].take(a^).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(var a: CaptureOCapturedBox) raises Never {mut calls} -> Int:
        calls += 1
        var total = a.value
        return total
    var a = CaptureOCapturedBox(1)
    var result = Capture[Never].take(a^).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 1)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(var a: CaptureOCapturedBox) raises Never {mut calls}:
        calls += 1
        var total = a.value
        _ = total
    var a = CaptureOCapturedBox(1)
    var result = Capture[Never].take(a^).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(var a: CaptureOCapturedBox) raises CaptureOCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a.value
        raise CaptureOCapturedFault(total)
    var a = CaptureOCapturedBox(1)
    var result = Capture[CaptureOCapturedFault].take(a^).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(var a: CaptureOCapturedBox) raises CaptureOCapturedFault {mut calls}:
        calls += 1
        var total = a.value
        raise CaptureOCapturedFault(total)
    var a = CaptureOCapturedBox(1)
    var result = Capture[CaptureOCapturedFault].take(a^).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 1)
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
