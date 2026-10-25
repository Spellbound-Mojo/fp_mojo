from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureZeroKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(var **options: Int) -> Int:
    var total = 0
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_pure_void_scalar(var **options: Int):
    var total = 0
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_scalar(var **options: Int) raises Never -> Int:
    var total = 0
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_never_void_scalar(var **options: Int) raises Never:
    var total = 0
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_scalar(var **options: Int) raises CaptureZeroKwFault -> Int:
    var total = 0
    for item in options.items(): total += item.value
    raise CaptureZeroKwFault(total)
def check_error_value_scalar() raises:
    var result = Capture[CaptureZeroKwFault].kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureZeroKwFault]
    assert_equal(result._err().value.code, 3)
def callback_error_void_scalar(var **options: Int) raises CaptureZeroKwFault:
    var total = 0
    for item in options.items(): total += item.value
    raise CaptureZeroKwFault(total)
def check_error_void_scalar() raises:
    var result = Capture[CaptureZeroKwFault].kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureZeroKwFault]
    assert_equal(result._err().value.code, 3)
def callback_pure_value_box(var **options: Int) -> Int:
    var total = 0
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_pure_void_box(var **options: Int):
    var total = 0
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_box(var **options: Int) raises Never -> Int:
    var total = 0
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_never_void_box(var **options: Int) raises Never:
    var total = 0
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var result = Capture[Never].kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_box(var **options: Int) raises CaptureZeroKwFault -> Int:
    var total = 0
    for item in options.items(): total += item.value
    raise CaptureZeroKwFault(total)
def check_error_value_box() raises:
    var result = Capture[CaptureZeroKwFault].kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureZeroKwFault]
    assert_equal(result._err().value.code, 3)
def callback_error_void_box(var **options: Int) raises CaptureZeroKwFault:
    var total = 0
    for item in options.items(): total += item.value
    raise CaptureZeroKwFault(total)
def check_error_void_box() raises:
    var result = Capture[CaptureZeroKwFault].kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureZeroKwFault]
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
