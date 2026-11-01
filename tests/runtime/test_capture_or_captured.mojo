from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOrCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(var a: Int, b: Int) {mut calls} -> Int:
        calls += 1
        var total = a + b
        return total
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).borrow(b).run(callback_pure_value_scalar)
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
    var result = Capture[Never].take(a).borrow(b).run(callback_pure_void_scalar)
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
    var result = Capture[Never].take(a).borrow(b).run(callback_never_value_scalar)
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
    var result = Capture[Never].take(a).borrow(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b, 2)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(var a: Int, b: Int) raises CaptureOrCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a + b
        raise CaptureOrCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureOrCapturedFault].take(a).borrow(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOrCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
    assert_equal(b, 2)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(var a: Int, b: Int) raises CaptureOrCapturedFault {mut calls}:
        calls += 1
        var total = a + b
        raise CaptureOrCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureOrCapturedFault].take(a).borrow(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOrCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
    assert_equal(b, 2)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(var a: CaptureOrCapturedBox, b: CaptureOrCapturedBox) {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        return total
    var a = CaptureOrCapturedBox(1)
    var b = CaptureOrCapturedBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
    assert_equal(b.value, 2)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(var a: CaptureOrCapturedBox, b: CaptureOrCapturedBox) {mut calls}:
        calls += 1
        var total = a.value + b.value
        _ = total
    var a = CaptureOrCapturedBox(1)
    var b = CaptureOrCapturedBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(var a: CaptureOrCapturedBox, b: CaptureOrCapturedBox) raises Never {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        return total
    var a = CaptureOrCapturedBox(1)
    var b = CaptureOrCapturedBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
    assert_equal(b.value, 2)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(var a: CaptureOrCapturedBox, b: CaptureOrCapturedBox) raises Never {mut calls}:
        calls += 1
        var total = a.value + b.value
        _ = total
    var a = CaptureOrCapturedBox(1)
    var b = CaptureOrCapturedBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(var a: CaptureOrCapturedBox, b: CaptureOrCapturedBox) raises CaptureOrCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        raise CaptureOrCapturedFault(total)
    var a = CaptureOrCapturedBox(1)
    var b = CaptureOrCapturedBox(2)
    var result = Capture[CaptureOrCapturedFault].take(a^).borrow(b).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOrCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
    assert_equal(b.value, 2)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(var a: CaptureOrCapturedBox, b: CaptureOrCapturedBox) raises CaptureOrCapturedFault {mut calls}:
        calls += 1
        var total = a.value + b.value
        raise CaptureOrCapturedFault(total)
    var a = CaptureOrCapturedBox(1)
    var b = CaptureOrCapturedBox(2)
    var result = Capture[CaptureOrCapturedFault].take(a^).borrow(b).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOrCapturedFault]
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
