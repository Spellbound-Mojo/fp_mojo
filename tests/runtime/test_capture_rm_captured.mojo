from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRmCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(a: Int, mut b: Int) {mut calls} -> Int:
        calls += 1
        b += 10
        var total = a + b
        return total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(a: Int, mut b: Int) {mut calls}:
        calls += 1
        b += 10
        var total = a + b
        _ = total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 12)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(a: Int, mut b: Int) raises Never {mut calls} -> Int:
        calls += 1
        b += 10
        var total = a + b
        return total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(a: Int, mut b: Int) raises Never {mut calls}:
        calls += 1
        b += 10
        var total = a + b
        _ = total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 12)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(a: Int, mut b: Int) raises CaptureRmCapturedFault {mut calls} -> Int:
        calls += 1
        b += 10
        var total = a + b
        raise CaptureRmCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureRmCapturedFault].borrow(a).mutable(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRmCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(a: Int, mut b: Int) raises CaptureRmCapturedFault {mut calls}:
        calls += 1
        b += 10
        var total = a + b
        raise CaptureRmCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureRmCapturedFault].borrow(a).mutable(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRmCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(a: CaptureRmCapturedBox, mut b: CaptureRmCapturedBox) {mut calls} -> Int:
        calls += 1
        b.value += 10
        var total = a.value + b.value
        return total
    var a = CaptureRmCapturedBox(1)
    var b = CaptureRmCapturedBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 13)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(a: CaptureRmCapturedBox, mut b: CaptureRmCapturedBox) {mut calls}:
        calls += 1
        b.value += 10
        var total = a.value + b.value
        _ = total
    var a = CaptureRmCapturedBox(1)
    var b = CaptureRmCapturedBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(a: CaptureRmCapturedBox, mut b: CaptureRmCapturedBox) raises Never {mut calls} -> Int:
        calls += 1
        b.value += 10
        var total = a.value + b.value
        return total
    var a = CaptureRmCapturedBox(1)
    var b = CaptureRmCapturedBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 13)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(a: CaptureRmCapturedBox, mut b: CaptureRmCapturedBox) raises Never {mut calls}:
        calls += 1
        b.value += 10
        var total = a.value + b.value
        _ = total
    var a = CaptureRmCapturedBox(1)
    var b = CaptureRmCapturedBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(a: CaptureRmCapturedBox, mut b: CaptureRmCapturedBox) raises CaptureRmCapturedFault {mut calls} -> Int:
        calls += 1
        b.value += 10
        var total = a.value + b.value
        raise CaptureRmCapturedFault(total)
    var a = CaptureRmCapturedBox(1)
    var b = CaptureRmCapturedBox(2)
    var result = Capture[CaptureRmCapturedFault].borrow(a).mutable(b).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRmCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 13)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(a: CaptureRmCapturedBox, mut b: CaptureRmCapturedBox) raises CaptureRmCapturedFault {mut calls}:
        calls += 1
        b.value += 10
        var total = a.value + b.value
        raise CaptureRmCapturedFault(total)
    var a = CaptureRmCapturedBox(1)
    var b = CaptureRmCapturedBox(2)
    var result = Capture[CaptureRmCapturedFault].borrow(a).mutable(b).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRmCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 13)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
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
