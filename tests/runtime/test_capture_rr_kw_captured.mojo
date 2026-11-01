from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRrKwCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRrKwCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(a: Int, b: Int, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        return total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(a, 1)
    assert_equal(b, 2)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(a: Int, b: Int, /, var **options: Int) {mut calls}:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 2)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(a: Int, b: Int, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        return total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(a, 1)
    assert_equal(b, 2)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(a: Int, b: Int, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 2)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(a: Int, b: Int, /, var **options: Int) raises CaptureRrKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        raise CaptureRrKwCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureRrKwCapturedFault].borrow(a).borrow(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
    assert_equal(a, 1)
    assert_equal(b, 2)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(a: Int, b: Int, /, var **options: Int) raises CaptureRrKwCapturedFault {mut calls}:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        raise CaptureRrKwCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureRrKwCapturedFault].borrow(a).borrow(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
    assert_equal(a, 1)
    assert_equal(b, 2)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(a: CaptureRrKwCapturedBox, b: CaptureRrKwCapturedBox, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureRrKwCapturedBox(1)
    var b = CaptureRrKwCapturedBox(2)
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(a.value, 1)
    assert_equal(b.value, 2)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(a: CaptureRrKwCapturedBox, b: CaptureRrKwCapturedBox, /, var **options: Int) {mut calls}:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureRrKwCapturedBox(1)
    var b = CaptureRrKwCapturedBox(2)
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 2)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(a: CaptureRrKwCapturedBox, b: CaptureRrKwCapturedBox, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureRrKwCapturedBox(1)
    var b = CaptureRrKwCapturedBox(2)
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(a.value, 1)
    assert_equal(b.value, 2)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(a: CaptureRrKwCapturedBox, b: CaptureRrKwCapturedBox, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureRrKwCapturedBox(1)
    var b = CaptureRrKwCapturedBox(2)
    var result = Capture[Never].borrow(a).borrow(b).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 2)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(a: CaptureRrKwCapturedBox, b: CaptureRrKwCapturedBox, /, var **options: Int) raises CaptureRrKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        raise CaptureRrKwCapturedFault(total)
    var a = CaptureRrKwCapturedBox(1)
    var b = CaptureRrKwCapturedBox(2)
    var result = Capture[CaptureRrKwCapturedFault].borrow(a).borrow(b).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
    assert_equal(a.value, 1)
    assert_equal(b.value, 2)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(a: CaptureRrKwCapturedBox, b: CaptureRrKwCapturedBox, /, var **options: Int) raises CaptureRrKwCapturedFault {mut calls}:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        raise CaptureRrKwCapturedFault(total)
    var a = CaptureRrKwCapturedBox(1)
    var b = CaptureRrKwCapturedBox(2)
    var result = Capture[CaptureRrKwCapturedFault].borrow(a).borrow(b).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
    assert_equal(a.value, 1)
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
