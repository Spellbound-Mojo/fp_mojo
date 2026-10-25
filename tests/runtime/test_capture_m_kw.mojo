from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(mut a: Int, /, var **options: Int) -> Int:
    a += 10
    var total = a
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 14)
    assert_equal(a, 11)
def callback_pure_void_scalar(mut a: Int, /, var **options: Int):
    a += 10
    var total = a
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_never_value_scalar(mut a: Int, /, var **options: Int) raises Never -> Int:
    a += 10
    var total = a
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 14)
    assert_equal(a, 11)
def callback_never_void_scalar(mut a: Int, /, var **options: Int) raises Never:
    a += 10
    var total = a
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_error_value_scalar(mut a: Int, /, var **options: Int) raises CaptureMKwFault -> Int:
    a += 10
    var total = a
    for item in options.items(): total += item.value
    raise CaptureMKwFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var result = Capture[CaptureMKwFault].mutable(a).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMKwFault]
    assert_equal(result._err().value.code, 14)
    assert_equal(a, 11)
def callback_error_void_scalar(mut a: Int, /, var **options: Int) raises CaptureMKwFault:
    a += 10
    var total = a
    for item in options.items(): total += item.value
    raise CaptureMKwFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var result = Capture[CaptureMKwFault].mutable(a).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMKwFault]
    assert_equal(result._err().value.code, 14)
    assert_equal(a, 11)
def callback_pure_value_box(mut a: CaptureMKwBox, /, var **options: Int) -> Int:
    a.value += 10
    var total = a.value
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var a = CaptureMKwBox(1)
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 14)
    assert_equal(a.value, 11)
def callback_pure_void_box(mut a: CaptureMKwBox, /, var **options: Int):
    a.value += 10
    var total = a.value
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureMKwBox(1)
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_never_value_box(mut a: CaptureMKwBox, /, var **options: Int) raises Never -> Int:
    a.value += 10
    var total = a.value
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var a = CaptureMKwBox(1)
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 14)
    assert_equal(a.value, 11)
def callback_never_void_box(mut a: CaptureMKwBox, /, var **options: Int) raises Never:
    a.value += 10
    var total = a.value
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureMKwBox(1)
    var result = Capture[Never].mutable(a).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_error_value_box(mut a: CaptureMKwBox, /, var **options: Int) raises CaptureMKwFault -> Int:
    a.value += 10
    var total = a.value
    for item in options.items(): total += item.value
    raise CaptureMKwFault(total)
def check_error_value_box() raises:
    var a = CaptureMKwBox(1)
    var result = Capture[CaptureMKwFault].mutable(a).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMKwFault]
    assert_equal(result._err().value.code, 14)
    assert_equal(a.value, 11)
def callback_error_void_box(mut a: CaptureMKwBox, /, var **options: Int) raises CaptureMKwFault:
    a.value += 10
    var total = a.value
    for item in options.items(): total += item.value
    raise CaptureMKwFault(total)
def check_error_void_box() raises:
    var a = CaptureMKwBox(1)
    var result = Capture[CaptureMKwFault].mutable(a).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMKwFault]
    assert_equal(result._err().value.code, 14)
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
