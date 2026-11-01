from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMixedOKwCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMixedOKwCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(var a: Int, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = a
        for item in options.items(): total += item.value
        return total
    var a = 1
    var result = Capture[CaptureMixedOKwCapturedFault].take(a).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 4)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(var a: Int, /, var **options: Int) {mut calls}:
        calls += 1
        var total = a
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var result = Capture[CaptureMixedOKwCapturedFault].take(a).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(var a: Int, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a
        for item in options.items(): total += item.value
        return total
    var a = 1
    var result = Capture[CaptureMixedOKwCapturedFault].take(a).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 4)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(var a: Int, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = a
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var result = Capture[CaptureMixedOKwCapturedFault].take(a).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(var a: Int, /, var **options: Int) raises CaptureMixedOKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a
        for item in options.items(): total += item.value
        raise CaptureMixedOKwCapturedFault(total)
    var a = 1
    var result = Capture[CaptureMixedOKwCapturedFault].take(a).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMixedOKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 4)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(var a: Int, /, var **options: Int) raises CaptureMixedOKwCapturedFault {mut calls}:
        calls += 1
        var total = a
        for item in options.items(): total += item.value
        raise CaptureMixedOKwCapturedFault(total)
    var a = 1
    var result = Capture[CaptureMixedOKwCapturedFault].take(a).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedOKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 4)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(var a: CaptureMixedOKwCapturedBox, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = a.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureMixedOKwCapturedBox(1)
    var result = Capture[CaptureMixedOKwCapturedFault].take(a^).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 4)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(var a: CaptureMixedOKwCapturedBox, /, var **options: Int) {mut calls}:
        calls += 1
        var total = a.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureMixedOKwCapturedBox(1)
    var result = Capture[CaptureMixedOKwCapturedFault].take(a^).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(var a: CaptureMixedOKwCapturedBox, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureMixedOKwCapturedBox(1)
    var result = Capture[CaptureMixedOKwCapturedFault].take(a^).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 4)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(var a: CaptureMixedOKwCapturedBox, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = a.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureMixedOKwCapturedBox(1)
    var result = Capture[CaptureMixedOKwCapturedFault].take(a^).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(var a: CaptureMixedOKwCapturedBox, /, var **options: Int) raises CaptureMixedOKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a.value
        for item in options.items(): total += item.value
        raise CaptureMixedOKwCapturedFault(total)
    var a = CaptureMixedOKwCapturedBox(1)
    var result = Capture[CaptureMixedOKwCapturedFault].take(a^).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMixedOKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 4)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(var a: CaptureMixedOKwCapturedBox, /, var **options: Int) raises CaptureMixedOKwCapturedFault {mut calls}:
        calls += 1
        var total = a.value
        for item in options.items(): total += item.value
        raise CaptureMixedOKwCapturedFault(total)
    var a = CaptureMixedOKwCapturedBox(1)
    var result = Capture[CaptureMixedOKwCapturedFault].take(a^).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedOKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 4)
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
