from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMmFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMmBox(Movable):
    var value: Int
def callback_pure_value_scalar(mut a: Int, mut b: Int) -> Int:
    a += 10
    b += 10
    var total = a + b
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 23)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_pure_void_scalar(mut a: Int, mut b: Int):
    a += 10
    b += 10
    var total = a + b
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_never_value_scalar(mut a: Int, mut b: Int) raises Never -> Int:
    a += 10
    b += 10
    var total = a + b
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 23)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_never_void_scalar(mut a: Int, mut b: Int) raises Never:
    a += 10
    b += 10
    var total = a + b
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).mutable(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_error_value_scalar(mut a: Int, mut b: Int) raises CaptureMmFault -> Int:
    a += 10
    b += 10
    var total = a + b
    raise CaptureMmFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMmFault].mutable(a).mutable(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMmFault]
    assert_equal(result._err().value.code, 23)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_error_void_scalar(mut a: Int, mut b: Int) raises CaptureMmFault:
    a += 10
    b += 10
    var total = a + b
    raise CaptureMmFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMmFault].mutable(a).mutable(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMmFault]
    assert_equal(result._err().value.code, 23)
    assert_equal(a, 11)
    assert_equal(b, 12)
def callback_pure_value_box(mut a: CaptureMmBox, mut b: CaptureMmBox) -> Int:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    return total
def check_pure_value_box() raises:
    var a = CaptureMmBox(1)
    var b = CaptureMmBox(2)
    var result = Capture[Never].mutable(a).mutable(b).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 23)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_pure_void_box(mut a: CaptureMmBox, mut b: CaptureMmBox):
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureMmBox(1)
    var b = CaptureMmBox(2)
    var result = Capture[Never].mutable(a).mutable(b).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_never_value_box(mut a: CaptureMmBox, mut b: CaptureMmBox) raises Never -> Int:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    return total
def check_never_value_box() raises:
    var a = CaptureMmBox(1)
    var b = CaptureMmBox(2)
    var result = Capture[Never].mutable(a).mutable(b).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 23)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_never_void_box(mut a: CaptureMmBox, mut b: CaptureMmBox) raises Never:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureMmBox(1)
    var b = CaptureMmBox(2)
    var result = Capture[Never].mutable(a).mutable(b).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_error_value_box(mut a: CaptureMmBox, mut b: CaptureMmBox) raises CaptureMmFault -> Int:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    raise CaptureMmFault(total)
def check_error_value_box() raises:
    var a = CaptureMmBox(1)
    var b = CaptureMmBox(2)
    var result = Capture[CaptureMmFault].mutable(a).mutable(b).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMmFault]
    assert_equal(result._err().value.code, 23)
    assert_equal(a.value, 11)
    assert_equal(b.value, 12)
def callback_error_void_box(mut a: CaptureMmBox, mut b: CaptureMmBox) raises CaptureMmFault:
    a.value += 10
    b.value += 10
    var total = a.value + b.value
    raise CaptureMmFault(total)
def check_error_void_box() raises:
    var a = CaptureMmBox(1)
    var b = CaptureMmBox(2)
    var result = Capture[CaptureMmFault].mutable(a).mutable(b).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMmFault]
    assert_equal(result._err().value.code, 23)
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
