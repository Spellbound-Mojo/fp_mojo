from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(var a: Int, /, var **options: Int) -> Int:
    var total = a
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 4)
def callback_pure_void_scalar(var a: Int, /, var **options: Int):
    var total = a
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_scalar(var a: Int, /, var **options: Int) raises Never -> Int:
    var total = a
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 4)
def callback_never_void_scalar(var a: Int, /, var **options: Int) raises Never:
    var total = a
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_scalar(var a: Int, /, var **options: Int) raises CaptureOKwFault -> Int:
    var total = a
    for item in options.items(): total += item.value
    raise CaptureOKwFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var result = Capture[CaptureOKwFault].take(a).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOKwFault]
    assert_equal(result._err().value.code, 4)
def callback_error_void_scalar(var a: Int, /, var **options: Int) raises CaptureOKwFault:
    var total = a
    for item in options.items(): total += item.value
    raise CaptureOKwFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var result = Capture[CaptureOKwFault].take(a).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOKwFault]
    assert_equal(result._err().value.code, 4)
def callback_pure_value_box(var a: CaptureOKwBox, /, var **options: Int) -> Int:
    var total = a.value
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var a = CaptureOKwBox(1)
    var result = Capture[Never].take(a^).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 4)
def callback_pure_void_box(var a: CaptureOKwBox, /, var **options: Int):
    var total = a.value
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureOKwBox(1)
    var result = Capture[Never].take(a^).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_box(var a: CaptureOKwBox, /, var **options: Int) raises Never -> Int:
    var total = a.value
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var a = CaptureOKwBox(1)
    var result = Capture[Never].take(a^).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 4)
def callback_never_void_box(var a: CaptureOKwBox, /, var **options: Int) raises Never:
    var total = a.value
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureOKwBox(1)
    var result = Capture[Never].take(a^).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_box(var a: CaptureOKwBox, /, var **options: Int) raises CaptureOKwFault -> Int:
    var total = a.value
    for item in options.items(): total += item.value
    raise CaptureOKwFault(total)
def check_error_value_box() raises:
    var a = CaptureOKwBox(1)
    var result = Capture[CaptureOKwFault].take(a^).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOKwFault]
    assert_equal(result._err().value.code, 4)
def callback_error_void_box(var a: CaptureOKwBox, /, var **options: Int) raises CaptureOKwFault:
    var total = a.value
    for item in options.items(): total += item.value
    raise CaptureOKwFault(total)
def check_error_void_box() raises:
    var a = CaptureOKwBox(1)
    var result = Capture[CaptureOKwFault].take(a^).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOKwFault]
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
