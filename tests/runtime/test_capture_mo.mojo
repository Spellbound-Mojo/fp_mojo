from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMoFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMoBox(Movable):
    var value: Int
def callback_pure_value_scalar(mut a: Int, var b: Int) -> Int:
    a += 10
    var total = a + b
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a, 11)
def callback_pure_void_scalar(mut a: Int, var b: Int):
    a += 10
    var total = a + b
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_never_value_scalar(mut a: Int, var b: Int) raises Never -> Int:
    a += 10
    var total = a + b
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a, 11)
def callback_never_void_scalar(mut a: Int, var b: Int) raises Never:
    a += 10
    var total = a + b
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].mutable(a).take(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_error_value_scalar(mut a: Int, var b: Int) raises CaptureMoFault -> Int:
    a += 10
    var total = a + b
    raise CaptureMoFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMoFault].mutable(a).take(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMoFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(a, 11)
def callback_error_void_scalar(mut a: Int, var b: Int) raises CaptureMoFault:
    a += 10
    var total = a + b
    raise CaptureMoFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureMoFault].mutable(a).take(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMoFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(a, 11)
def callback_pure_value_box(mut a: CaptureMoBox, var b: CaptureMoBox) -> Int:
    a.value += 10
    var total = a.value + b.value
    return total
def check_pure_value_box() raises:
    var a = CaptureMoBox(1)
    var b = CaptureMoBox(2)
    var result = Capture[Never].mutable(a).take(b^).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a.value, 11)
def callback_pure_void_box(mut a: CaptureMoBox, var b: CaptureMoBox):
    a.value += 10
    var total = a.value + b.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureMoBox(1)
    var b = CaptureMoBox(2)
    var result = Capture[Never].mutable(a).take(b^).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_never_value_box(mut a: CaptureMoBox, var b: CaptureMoBox) raises Never -> Int:
    a.value += 10
    var total = a.value + b.value
    return total
def check_never_value_box() raises:
    var a = CaptureMoBox(1)
    var b = CaptureMoBox(2)
    var result = Capture[Never].mutable(a).take(b^).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a.value, 11)
def callback_never_void_box(mut a: CaptureMoBox, var b: CaptureMoBox) raises Never:
    a.value += 10
    var total = a.value + b.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureMoBox(1)
    var b = CaptureMoBox(2)
    var result = Capture[Never].mutable(a).take(b^).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_error_value_box(mut a: CaptureMoBox, var b: CaptureMoBox) raises CaptureMoFault -> Int:
    a.value += 10
    var total = a.value + b.value
    raise CaptureMoFault(total)
def check_error_value_box() raises:
    var a = CaptureMoBox(1)
    var b = CaptureMoBox(2)
    var result = Capture[CaptureMoFault].mutable(a).take(b^).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMoFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(a.value, 11)
def callback_error_void_box(mut a: CaptureMoBox, var b: CaptureMoBox) raises CaptureMoFault:
    a.value += 10
    var total = a.value + b.value
    raise CaptureMoFault(total)
def check_error_void_box() raises:
    var a = CaptureMoBox(1)
    var b = CaptureMoBox(2)
    var result = Capture[CaptureMoFault].mutable(a).take(b^).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMoFault]
    assert_equal(result._err().value.code, 13)
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
