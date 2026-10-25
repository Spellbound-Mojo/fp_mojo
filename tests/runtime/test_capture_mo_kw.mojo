from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMoKwFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoKwBox(Movable):
    var value: Int
def callback_pure_value_scalar(mut a: Int, var b: Int, /, var **options: Int) -> Int:
    a += 10
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).kwargs(extra=3).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a, 11)
def callback_pure_void_scalar(mut a: Int, var b: Int, /, var **options: Int):
    a += 10
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).kwargs(extra=3).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_never_value_scalar(mut a: Int, var b: Int, /, var **options: Int) raises Never -> Int:
    a += 10
    var total = a + b
    for item in options.items(): total += item.value
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).kwargs(extra=3).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a, 11)
def callback_never_void_scalar(mut a: Int, var b: Int, /, var **options: Int) raises Never:
    a += 10
    var total = a + b
    for item in options.items(): total += item.value
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).kwargs(extra=3).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_error_value_scalar(mut a: Int, var b: Int, /, var **options: Int) raises CaptureMoKwFault -> Int:
    a += 10
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureMoKwFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMoKwFault].mutable(a).take(b).kwargs(extra=3).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMoKwFault]
    assert_equal(result._err().value.code, 16)
    assert_equal(a, 11)
def callback_error_void_scalar(mut a: Int, var b: Int, /, var **options: Int) raises CaptureMoKwFault:
    a += 10
    var total = a + b
    for item in options.items(): total += item.value
    raise CaptureMoKwFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMoKwFault].mutable(a).take(b).kwargs(extra=3).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMoKwFault]
    assert_equal(result._err().value.code, 16)
    assert_equal(a, 11)
def callback_pure_value_box(mut a: CaptureMoKwBox, var b: CaptureMoKwBox, /, var **options: Int) -> Int:
    a.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_pure_value_box() raises:
    var a = CaptureMoKwBox(1)
    var b = CaptureMoKwBox(2)
    var result = Capture[Never].mutable(a).take(b^).kwargs(extra=3).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a.value, 11)
def callback_pure_void_box(mut a: CaptureMoKwBox, var b: CaptureMoKwBox, /, var **options: Int):
    a.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureMoKwBox(1)
    var b = CaptureMoKwBox(2)
    var result = Capture[Never].mutable(a).take(b^).kwargs(extra=3).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_never_value_box(mut a: CaptureMoKwBox, var b: CaptureMoKwBox, /, var **options: Int) raises Never -> Int:
    a.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    return total
def check_never_value_box() raises:
    var a = CaptureMoKwBox(1)
    var b = CaptureMoKwBox(2)
    var result = Capture[Never].mutable(a).take(b^).kwargs(extra=3).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 16)
    assert_equal(a.value, 11)
def callback_never_void_box(mut a: CaptureMoKwBox, var b: CaptureMoKwBox, /, var **options: Int) raises Never:
    a.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureMoKwBox(1)
    var b = CaptureMoKwBox(2)
    var result = Capture[Never].mutable(a).take(b^).kwargs(extra=3).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_error_value_box(mut a: CaptureMoKwBox, var b: CaptureMoKwBox, /, var **options: Int) raises CaptureMoKwFault -> Int:
    a.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureMoKwFault(total)
def check_error_value_box() raises:
    var a = CaptureMoKwBox(1)
    var b = CaptureMoKwBox(2)
    var result = Capture[CaptureMoKwFault].mutable(a).take(b^).kwargs(extra=3).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMoKwFault]
    assert_equal(result._err().value.code, 16)
    assert_equal(a.value, 11)
def callback_error_void_box(mut a: CaptureMoKwBox, var b: CaptureMoKwBox, /, var **options: Int) raises CaptureMoKwFault:
    a.value += 10
    var total = a.value + b.value
    for item in options.items(): total += item.value
    raise CaptureMoKwFault(total)
def check_error_void_box() raises:
    var a = CaptureMoKwBox(1)
    var b = CaptureMoKwBox(2)
    var result = Capture[CaptureMoKwFault].mutable(a).take(b^).kwargs(extra=3).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMoKwFault]
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
