from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMmKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(mut a: Int, mut b: Int, /, var **options: Int) -> Int:
    a += 10
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 26)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_pure_void_scalar(mut a: Int, mut b: Int, /, var **options: Int):
    a += 10
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_never_value_scalar(mut a: Int, mut b: Int, /, var **options: Int) raises Never -> Int:
    a += 10
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 26)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_never_void_scalar(mut a: Int, mut b: Int, /, var **options: Int) raises Never:
    a += 10
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_error_value_scalar(mut a: Int, mut b: Int, /, var **options: Int) raises CaptureMmKwFault -> Int:
    a += 10
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureMmKwFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMmKwFault].mutable(a).mutable(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMmKwFault]
    assert_equal(result._err().value.code, 26)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_error_void_scalar(mut a: Int, mut b: Int, /, var **options: Int) raises CaptureMmKwFault:
    a += 10
    b += 10
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureMmKwFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMmKwFault].mutable(a).mutable(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMmKwFault]
    assert_equal(result._err().value.code, 26)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_pure_value_box(mut a: CaptureMmKwBox, mut b: CaptureMmKwBox, /, var **options: Int) -> Int:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var a = CaptureMmKwBox(1)
    var b = CaptureMmKwBox(2)
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 26)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_pure_void_box(mut a: CaptureMmKwBox, mut b: CaptureMmKwBox, /, var **options: Int):
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureMmKwBox(1)
    var b = CaptureMmKwBox(2)
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_never_value_box(mut a: CaptureMmKwBox, mut b: CaptureMmKwBox, /, var **options: Int) raises Never -> Int:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var a = CaptureMmKwBox(1)
    var b = CaptureMmKwBox(2)
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 26)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_never_void_box(mut a: CaptureMmKwBox, mut b: CaptureMmKwBox, /, var **options: Int) raises Never:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureMmKwBox(1)
    var b = CaptureMmKwBox(2)
    var result = Capture[Never].mutable(a).mutable(b).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_error_value_box(mut a: CaptureMmKwBox, mut b: CaptureMmKwBox, /, var **options: Int) raises CaptureMmKwFault -> Int:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureMmKwFault(total)
def check_error_value_box() raises:
    var a = CaptureMmKwBox(1)
    var b = CaptureMmKwBox(2)
    var result = Capture[CaptureMmKwFault].mutable(a).mutable(b).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMmKwFault]
    assert_equal(result._err().value.code, 26)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_error_void_box(mut a: CaptureMmKwBox, mut b: CaptureMmKwBox, /, var **options: Int) raises CaptureMmKwFault:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureMmKwFault(total)
def check_error_void_box() raises:
    var a = CaptureMmKwBox(1)
    var b = CaptureMmKwBox(2)
    var result = Capture[CaptureMmKwFault].mutable(a).mutable(b).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMmKwFault]
    assert_equal(result._err().value.code, 26)
    assert_equal(a.value, 11)
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
