from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRoKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(a: Int, var b: Int, /, var **options: Int) -> Int:
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
    assert_equal(a, 1)
def callback_pure_void_scalar(a: Int, var b: Int, /, var **options: Int):
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def callback_never_value_scalar(a: Int, var b: Int, /, var **options: Int) raises Never -> Int:
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
    assert_equal(a, 1)
def callback_never_void_scalar(a: Int, var b: Int, /, var **options: Int) raises Never:
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def callback_error_value_scalar(a: Int, var b: Int, /, var **options: Int) raises CaptureRoKwFault -> Int:
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureRoKwFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRoKwFault].borrow(a).take(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRoKwFault]
    assert_equal(result._err().value.code, 6)
    assert_equal(a, 1)
def callback_error_void_scalar(a: Int, var b: Int, /, var **options: Int) raises CaptureRoKwFault:
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureRoKwFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRoKwFault].borrow(a).take(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRoKwFault]
    assert_equal(result._err().value.code, 6)
    assert_equal(a, 1)
def callback_pure_value_box(a: CaptureRoKwBox, var b: CaptureRoKwBox, /, var **options: Int) -> Int:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var a = CaptureRoKwBox(1)
    var b = CaptureRoKwBox(2)
    var result = Capture[Never].borrow(a).take(b^).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
    assert_equal(a.value, 1)
def callback_pure_void_box(a: CaptureRoKwBox, var b: CaptureRoKwBox, /, var **options: Int):
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureRoKwBox(1)
    var b = CaptureRoKwBox(2)
    var result = Capture[Never].borrow(a).take(b^).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def callback_never_value_box(a: CaptureRoKwBox, var b: CaptureRoKwBox, /, var **options: Int) raises Never -> Int:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var a = CaptureRoKwBox(1)
    var b = CaptureRoKwBox(2)
    var result = Capture[Never].borrow(a).take(b^).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 6)
    assert_equal(a.value, 1)
def callback_never_void_box(a: CaptureRoKwBox, var b: CaptureRoKwBox, /, var **options: Int) raises Never:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureRoKwBox(1)
    var b = CaptureRoKwBox(2)
    var result = Capture[Never].borrow(a).take(b^).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def callback_error_value_box(a: CaptureRoKwBox, var b: CaptureRoKwBox, /, var **options: Int) raises CaptureRoKwFault -> Int:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureRoKwFault(total)
def check_error_value_box() raises:
    var a = CaptureRoKwBox(1)
    var b = CaptureRoKwBox(2)
    var result = Capture[CaptureRoKwFault].borrow(a).take(b^).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRoKwFault]
    assert_equal(result._err().value.code, 6)
    assert_equal(a.value, 1)
def callback_error_void_box(a: CaptureRoKwBox, var b: CaptureRoKwBox, /, var **options: Int) raises CaptureRoKwFault:
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureRoKwFault(total)
def check_error_void_box() raises:
    var a = CaptureRoKwBox(1)
    var b = CaptureRoKwBox(2)
    var result = Capture[CaptureRoKwFault].borrow(a).take(b^).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRoKwFault]
    assert_equal(result._err().value.code, 6)
    assert_equal(a.value, 1)
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
