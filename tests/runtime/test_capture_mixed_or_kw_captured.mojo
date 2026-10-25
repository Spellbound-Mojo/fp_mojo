from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMixedOrKwCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMixedOrKwCapturedBox(Movable):
    var value: Int
def check_pure_value_scalar() raises:
    var calls = 0
    def callback_pure_value_scalar(var a: Int, b: Int, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        return total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a).borrow(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(b, 2)
def check_pure_void_scalar() raises:
    var calls = 0
    def callback_pure_void_scalar(var a: Int, b: Int, /, var **options: Int) {mut calls}:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a).borrow(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b, 2)
def check_never_value_scalar() raises:
    var calls = 0
    def callback_never_value_scalar(var a: Int, b: Int, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        return total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a).borrow(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(b, 2)
def check_never_void_scalar() raises:
    var calls = 0
    def callback_never_void_scalar(var a: Int, b: Int, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        _ = total
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a).borrow(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b, 2)
def check_error_value_scalar() raises:
    var calls = 0
    def callback_error_value_scalar(var a: Int, b: Int, /, var **options: Int) raises CaptureMixedOrKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        raise CaptureMixedOrKwCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a).borrow(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMixedOrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
    assert_equal(b, 2)
def check_error_void_scalar() raises:
    var calls = 0
    def callback_error_void_scalar(var a: Int, b: Int, /, var **options: Int) raises CaptureMixedOrKwCapturedFault {mut calls}:
        calls += 1
        var total = a + b
        for item in options.items(): total += item.value
        raise CaptureMixedOrKwCapturedFault(total)
    var a = 1
    var b = 2
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a).borrow(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedOrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
    assert_equal(b, 2)
def check_pure_value_box() raises:
    var calls = 0
    def callback_pure_value_box(var a: CaptureMixedOrKwCapturedBox, b: CaptureMixedOrKwCapturedBox, /, var **options: Int) {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureMixedOrKwCapturedBox(1)
    var b = CaptureMixedOrKwCapturedBox(2)
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a^).borrow(b).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(b.value, 2)
def check_pure_void_box() raises:
    var calls = 0
    def callback_pure_void_box(var a: CaptureMixedOrKwCapturedBox, b: CaptureMixedOrKwCapturedBox, /, var **options: Int) {mut calls}:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureMixedOrKwCapturedBox(1)
    var b = CaptureMixedOrKwCapturedBox(2)
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a^).borrow(b).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def check_never_value_box() raises:
    var calls = 0
    def callback_never_value_box(var a: CaptureMixedOrKwCapturedBox, b: CaptureMixedOrKwCapturedBox, /, var **options: Int) raises Never {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        return total
    var a = CaptureMixedOrKwCapturedBox(1)
    var b = CaptureMixedOrKwCapturedBox(2)
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a^).borrow(b).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(calls, 1)
    assert_equal(result._ok().value, 6)
    assert_equal(b.value, 2)
def check_never_void_box() raises:
    var calls = 0
    def callback_never_void_box(var a: CaptureMixedOrKwCapturedBox, b: CaptureMixedOrKwCapturedBox, /, var **options: Int) raises Never {mut calls}:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        _ = total
    var a = CaptureMixedOrKwCapturedBox(1)
    var b = CaptureMixedOrKwCapturedBox(2)
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a^).borrow(b).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(calls, 1)
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def check_error_value_box() raises:
    var calls = 0
    def callback_error_value_box(var a: CaptureMixedOrKwCapturedBox, b: CaptureMixedOrKwCapturedBox, /, var **options: Int) raises CaptureMixedOrKwCapturedFault {mut calls} -> Int:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        raise CaptureMixedOrKwCapturedFault(total)
    var a = CaptureMixedOrKwCapturedBox(1)
    var b = CaptureMixedOrKwCapturedBox(2)
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a^).borrow(b).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMixedOrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
    assert_equal(b.value, 2)
def check_error_void_box() raises:
    var calls = 0
    def callback_error_void_box(var a: CaptureMixedOrKwCapturedBox, b: CaptureMixedOrKwCapturedBox, /, var **options: Int) raises CaptureMixedOrKwCapturedFault {mut calls}:
        calls += 1
        var total = a.value + b.value
        for item in options.items(): total += item.value
        raise CaptureMixedOrKwCapturedFault(total)
    var a = CaptureMixedOrKwCapturedBox(1)
    var b = CaptureMixedOrKwCapturedBox(2)
    var result = Capture[CaptureMixedOrKwCapturedFault].take(a^).borrow(b).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMixedOrKwCapturedFault]
    assert_equal(calls, 1)
    assert_equal(result._err().value.code, 6)
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
