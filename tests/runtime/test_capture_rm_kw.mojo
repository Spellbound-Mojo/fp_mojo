from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRmKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(a: Int, mut b: Int, /, var **options: Int) -> Int:
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_pure_void_scalar(a: Int, mut b: Int, /, var **options: Int):
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_never_value_scalar(a: Int, mut b: Int, /, var **options: Int) raises Never -> Int:
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_never_void_scalar(a: Int, mut b: Int, /, var **options: Int) raises Never:
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_error_value_scalar(a: Int, mut b: Int, /, var **options: Int) raises CaptureRmKwFault -> Int:
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureRmKwFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRmKwFault].borrow(a).mutable(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRmKwFault]
    assert_equal(result._err().value.code, 16)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_error_void_scalar(a: Int, mut b: Int, /, var **options: Int) raises CaptureRmKwFault:
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureRmKwFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRmKwFault].borrow(a).mutable(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRmKwFault]
    assert_equal(result._err().value.code, 16)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_pure_value_box(a: CaptureRmKwBox, mut b: CaptureRmKwBox, /, var **options: Int) -> Int:
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var a = CaptureRmKwBox(1)
    var b = CaptureRmKwBox(2)
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_pure_void_box(a: CaptureRmKwBox, mut b: CaptureRmKwBox, /, var **options: Int):
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureRmKwBox(1)
    var b = CaptureRmKwBox(2)
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_never_value_box(a: CaptureRmKwBox, mut b: CaptureRmKwBox, /, var **options: Int) raises Never -> Int:
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var a = CaptureRmKwBox(1)
    var b = CaptureRmKwBox(2)
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_never_void_box(a: CaptureRmKwBox, mut b: CaptureRmKwBox, /, var **options: Int) raises Never:
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureRmKwBox(1)
    var b = CaptureRmKwBox(2)
    var result = Capture[Never].borrow(a).mutable(b).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_error_value_box(a: CaptureRmKwBox, mut b: CaptureRmKwBox, /, var **options: Int) raises CaptureRmKwFault -> Int:
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureRmKwFault(total)
def check_error_value_box() raises:
    var a = CaptureRmKwBox(1)
    var b = CaptureRmKwBox(2)
    var result = Capture[CaptureRmKwFault].borrow(a).mutable(b).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRmKwFault]
    assert_equal(result._err().value.code, 16)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_error_void_box(a: CaptureRmKwBox, mut b: CaptureRmKwBox, /, var **options: Int) raises CaptureRmKwFault:
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureRmKwFault(total)
def check_error_void_box() raises:
    var a = CaptureRmKwBox(1)
    var b = CaptureRmKwBox(2)
    var result = Capture[CaptureRmKwFault].borrow(a).mutable(b).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRmKwFault]
    assert_equal(result._err().value.code, 16)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
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
