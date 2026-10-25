from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRBox(Movable):
    var value: Int
def callback_pure_value_scalar(a: Int) -> Int:
    var total = a
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
    assert_equal(a, 1)
def callback_pure_void_scalar(a: Int):
    var total = a
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def callback_never_value_scalar(a: Int) raises Never -> Int:
    var total = a
    return total
def check_never_value_scalar() raises:
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
    assert_equal(a, 1)
def callback_never_void_scalar(a: Int) raises Never:
    var total = a
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var result = Capture[Never].borrow(a).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def callback_error_value_scalar(a: Int) raises CaptureRFault -> Int:
    var total = a
    raise CaptureRFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var result = Capture[CaptureRFault].borrow(a).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRFault]
    assert_equal(result._err().value.code, 1)
    assert_equal(a, 1)
def callback_error_void_scalar(a: Int) raises CaptureRFault:
    var total = a
    raise CaptureRFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var result = Capture[CaptureRFault].borrow(a).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRFault]
    assert_equal(result._err().value.code, 1)
    assert_equal(a, 1)
def callback_pure_value_box(a: CaptureRBox) -> Int:
    var total = a.value
    return total
def check_pure_value_box() raises:
    var a = CaptureRBox(1)
    var result = Capture[Never].borrow(a).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
    assert_equal(a.value, 1)
def callback_pure_void_box(a: CaptureRBox):
    var total = a.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureRBox(1)
    var result = Capture[Never].borrow(a).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def callback_never_value_box(a: CaptureRBox) raises Never -> Int:
    var total = a.value
    return total
def check_never_value_box() raises:
    var a = CaptureRBox(1)
    var result = Capture[Never].borrow(a).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
    assert_equal(a.value, 1)
def callback_never_void_box(a: CaptureRBox) raises Never:
    var total = a.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureRBox(1)
    var result = Capture[Never].borrow(a).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def callback_error_value_box(a: CaptureRBox) raises CaptureRFault -> Int:
    var total = a.value
    raise CaptureRFault(total)
def check_error_value_box() raises:
    var a = CaptureRBox(1)
    var result = Capture[CaptureRFault].borrow(a).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRFault]
    assert_equal(result._err().value.code, 1)
    assert_equal(a.value, 1)
def callback_error_void_box(a: CaptureRBox) raises CaptureRFault:
    var total = a.value
    raise CaptureRFault(total)
def check_error_void_box() raises:
    var a = CaptureRBox(1)
    var result = Capture[CaptureRFault].borrow(a).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRFault]
    assert_equal(result._err().value.code, 1)
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
