from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMixedZeroKwCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMixedZeroKwCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        return total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(var **options: Int) {mut calls}:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        _ = total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        return total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        _ = total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(var **options: Int) raises CaptureMixedZeroKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        raise CaptureMixedZeroKwCapturedFault(total)
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMixedZeroKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(var **options: Int) raises CaptureMixedZeroKwCapturedFault {mut calls}:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        raise CaptureMixedZeroKwCapturedFault(total)
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedZeroKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        return total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(var **options: Int) {mut calls}:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        _ = total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        return total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 3)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        _ = total
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(var **options: Int) raises CaptureMixedZeroKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        raise CaptureMixedZeroKwCapturedFault(total)
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMixedZeroKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(var **options: Int) raises CaptureMixedZeroKwCapturedFault {mut calls}:
        calls += 1
        var total = 0
        for item in options.items(): total += item.value
        raise CaptureMixedZeroKwCapturedFault(total)
    var result = Capture[CaptureMixedZeroKwCapturedFault].kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedZeroKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 3)
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
