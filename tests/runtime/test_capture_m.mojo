from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureMFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureMBox(Movable):
    var value: Int
def callback_pure_value_scalar(mut a: Int) -> Int:
    a += 10
    var total = a
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 11)
    assert_equal(a, 11)
def callback_pure_void_scalar(mut a: Int):
    a += 10
    var total = a
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_never_value_scalar(mut a: Int) raises Never -> Int:
    a += 10
    var total = a
    return total
def check_never_value_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 11)
    assert_equal(a, 11)
def callback_never_void_scalar(mut a: Int) raises Never:
    a += 10
    var total = a
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var result = Capture[Never].mutable(a).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 11)
def callback_error_value_scalar(mut a: Int) raises CaptureMFault -> Int:
    a += 10
    var total = a
    raise CaptureMFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var result = Capture[CaptureMFault].mutable(a).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureMFault]
    assert_equal(result._err().value.code, 11)
    assert_equal(a, 11)
def callback_error_void_scalar(mut a: Int) raises CaptureMFault:
    a += 10
    var total = a
    raise CaptureMFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var result = Capture[CaptureMFault].mutable(a).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureMFault]
    assert_equal(result._err().value.code, 11)
    assert_equal(a, 11)
def callback_pure_value_box(mut a: CaptureMBox) -> Int:
    a.value += 10
    var total = a.value
    return total
def check_pure_value_box() raises:
    var a = CaptureMBox(1)
    var result = Capture[Never].mutable(a).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 11)
    assert_equal(a.value, 11)
def callback_pure_void_box(mut a: CaptureMBox):
    a.value += 10
    var total = a.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureMBox(1)
    var result = Capture[Never].mutable(a).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_never_value_box(mut a: CaptureMBox) raises Never -> Int:
    a.value += 10
    var total = a.value
    return total
def check_never_value_box() raises:
    var a = CaptureMBox(1)
    var result = Capture[Never].mutable(a).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 11)
    assert_equal(a.value, 11)
def callback_never_void_box(mut a: CaptureMBox) raises Never:
    a.value += 10
    var total = a.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureMBox(1)
    var result = Capture[Never].mutable(a).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 11)
def callback_error_value_box(mut a: CaptureMBox) raises CaptureMFault -> Int:
    a.value += 10
    var total = a.value
    raise CaptureMFault(total)
def check_error_value_box() raises:
    var a = CaptureMBox(1)
    var result = Capture[CaptureMFault].mutable(a).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureMFault]
    assert_equal(result._err().value.code, 11)
    assert_equal(a.value, 11)
def callback_error_void_box(mut a: CaptureMBox) raises CaptureMFault:
    a.value += 10
    var total = a.value
    raise CaptureMFault(total)
def check_error_void_box() raises:
    var a = CaptureMBox(1)
    var result = Capture[CaptureMFault].mutable(a).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureMFault]
    assert_equal(result._err().value.code, 11)
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
