from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMixedMoKwCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMixedMoKwCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(mut a: Int, var b: Int, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        a += 10
        var total = a + b
        for item in options.items(): total += item.value
        return total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 16)
    assert_equal(a, 11)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(mut a: Int, var b: Int, /, var **options: Int) {mut calls}:
        calls += 1
        a += 10
        var total = a + b
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(mut a: Int, var b: Int, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        a += 10
        var total = a + b
        for item in options.items(): total += item.value
        return total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 16)
    assert_equal(a, 11)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(mut a: Int, var b: Int, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        a += 10
        var total = a + b
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(mut a: Int, var b: Int, /, var **options: Int) raises CaptureMixedMoKwCapturedFault {mut calls} -> Int:
        calls += 1
        a += 10
        var total = a + b
        for item in options.items(): total += item.value
        raise CaptureMixedMoKwCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMixedMoKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 16)
    assert_equal(a, 11)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(mut a: Int, var b: Int, /, var **options: Int) raises CaptureMixedMoKwCapturedFault {mut calls}:
        calls += 1
        a += 10
        var total = a + b
        for item in options.items(): total += item.value
        raise CaptureMixedMoKwCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedMoKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 16)
    assert_equal(a, 11)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(mut a: CaptureMixedMoKwCapturedBox, var b: CaptureMixedMoKwCapturedBox, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        a.value += 10
        var total = a.value + b.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureMixedMoKwCapturedBox(1)
    var b = CaptureMixedMoKwCapturedBox(2)
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b^).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 16)
    assert_equal(a.value, 11)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(mut a: CaptureMixedMoKwCapturedBox, var b: CaptureMixedMoKwCapturedBox, /, var **options: Int) {mut calls}:
        calls += 1
        a.value += 10
        var total = a.value + b.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureMixedMoKwCapturedBox(1)
    var b = CaptureMixedMoKwCapturedBox(2)
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b^).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(mut a: CaptureMixedMoKwCapturedBox, var b: CaptureMixedMoKwCapturedBox, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        a.value += 10
        var total = a.value + b.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureMixedMoKwCapturedBox(1)
    var b = CaptureMixedMoKwCapturedBox(2)
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b^).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 16)
    assert_equal(a.value, 11)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(mut a: CaptureMixedMoKwCapturedBox, var b: CaptureMixedMoKwCapturedBox, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        a.value += 10
        var total = a.value + b.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureMixedMoKwCapturedBox(1)
    var b = CaptureMixedMoKwCapturedBox(2)
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b^).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(mut a: CaptureMixedMoKwCapturedBox, var b: CaptureMixedMoKwCapturedBox, /, var **options: Int) raises CaptureMixedMoKwCapturedFault {mut calls} -> Int:
        calls += 1
        a.value += 10
        var total = a.value + b.value
        for item in options.items(): total += item.value
        raise CaptureMixedMoKwCapturedFault(total)
    var a = CaptureMixedMoKwCapturedBox(1)
    var b = CaptureMixedMoKwCapturedBox(2)
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b^).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMixedMoKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 16)
    assert_equal(a.value, 11)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(mut a: CaptureMixedMoKwCapturedBox, var b: CaptureMixedMoKwCapturedBox, /, var **options: Int) raises CaptureMixedMoKwCapturedFault {mut calls}:
        calls += 1
        a.value += 10
        var total = a.value + b.value
        for item in options.items(): total += item.value
        raise CaptureMixedMoKwCapturedFault(total)
    var a = CaptureMixedMoKwCapturedBox(1)
    var b = CaptureMixedMoKwCapturedBox(2)
    var result = Capture[CaptureMixedMoKwCapturedFault].mutable(a).take(b^).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedMoKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 16)
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
