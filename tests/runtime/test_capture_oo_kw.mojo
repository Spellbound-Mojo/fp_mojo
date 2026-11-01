from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOoKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(var a: Int, var b: Int, /, var **options: Int) -> Int:
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
def callback_pure_void_scalar(var a: Int, var b: Int, /, var **options: Int):
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_scalar(var a: Int, var b: Int, /, var **options: Int) raises Never -> Int:
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
def callback_never_void_scalar(var a: Int, var b: Int, /, var **options: Int) raises Never:
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_scalar(var a: Int, var b: Int, /, var **options: Int) raises CaptureOoKwFault -> Int:
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureOoKwFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOoKwFault].take(a).take(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOoKwFault]
    assert_equal(result._err().value.code, 6)
def callback_error_void_scalar(var a: Int, var b: Int, /, var **options: Int) raises CaptureOoKwFault:
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureOoKwFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOoKwFault].take(a).take(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOoKwFault]
    assert_equal(result._err().value.code, 6)
def callback_pure_value_box(var a: CaptureOoKwBox, var b: CaptureOoKwBox, /, var **options: Int) -> Int:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var a = CaptureOoKwBox(1)
    var b = CaptureOoKwBox(2)
    var result = Capture[Never].take(a^).take(b^).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
def callback_pure_void_box(var a: CaptureOoKwBox, var b: CaptureOoKwBox, /, var **options: Int):
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureOoKwBox(1)
    var b = CaptureOoKwBox(2)
    var result = Capture[Never].take(a^).take(b^).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_box(var a: CaptureOoKwBox, var b: CaptureOoKwBox, /, var **options: Int) raises Never -> Int:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var a = CaptureOoKwBox(1)
    var b = CaptureOoKwBox(2)
    var result = Capture[Never].take(a^).take(b^).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
def callback_never_void_box(var a: CaptureOoKwBox, var b: CaptureOoKwBox, /, var **options: Int) raises Never:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureOoKwBox(1)
    var b = CaptureOoKwBox(2)
    var result = Capture[Never].take(a^).take(b^).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_box(var a: CaptureOoKwBox, var b: CaptureOoKwBox, /, var **options: Int) raises CaptureOoKwFault -> Int:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureOoKwFault(total)
def check_error_value_box() raises:
    var a = CaptureOoKwBox(1)
    var b = CaptureOoKwBox(2)
    var result = Capture[CaptureOoKwFault].take(a^).take(b^).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOoKwFault]
    assert_equal(result._err().value.code, 6)
def callback_error_void_box(var a: CaptureOoKwBox, var b: CaptureOoKwBox, /, var **options: Int) raises CaptureOoKwFault:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureOoKwFault(total)
def check_error_void_box() raises:
    var a = CaptureOoKwBox(1)
    var b = CaptureOoKwBox(2)
    var result = Capture[CaptureOoKwFault].take(a^).take(b^).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOoKwFault]
    assert_equal(result._err().value.code, 6)
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
