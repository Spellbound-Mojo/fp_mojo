from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRoFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRoBox(Movable):
    var value: Int
def callback_pure_value_scalar(a: Int, var b: Int) -> Int:
    var total = a + b
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(a, 1)
def callback_pure_void_scalar(a: Int, var b: Int):
    var total = a + b
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def callback_never_value_scalar(a: Int, var b: Int) raises Never -> Int:
    var total = a + b
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(a, 1)
def callback_never_void_scalar(a: Int, var b: Int) raises Never:
    var total = a + b
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).take(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
def callback_error_value_scalar(a: Int, var b: Int) raises CaptureRoFault -> Int:
    var total = a + b
    raise CaptureRoFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRoFault].borrow(a).take(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRoFault]
    assert_equal(result._err().value.code, 3)
    assert_equal(a, 1)
def callback_error_void_scalar(a: Int, var b: Int) raises CaptureRoFault:
    var total = a + b
    raise CaptureRoFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRoFault].borrow(a).take(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRoFault]
    assert_equal(result._err().value.code, 3)
    assert_equal(a, 1)
def callback_pure_value_box(a: CaptureRoBox, var b: CaptureRoBox) -> Int:
    var total = a.value + b.value
    return total
def check_pure_value_box() raises:
    var a = CaptureRoBox(1)
    var b = CaptureRoBox(2)
    var result = Capture[Never].borrow(a).take(b^).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(a.value, 1)
def callback_pure_void_box(a: CaptureRoBox, var b: CaptureRoBox):
    var total = a.value + b.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureRoBox(1)
    var b = CaptureRoBox(2)
    var result = Capture[Never].borrow(a).take(b^).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def callback_never_value_box(a: CaptureRoBox, var b: CaptureRoBox) raises Never -> Int:
    var total = a.value + b.value
    return total
def check_never_value_box() raises:
    var a = CaptureRoBox(1)
    var b = CaptureRoBox(2)
    var result = Capture[Never].borrow(a).take(b^).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(a.value, 1)
def callback_never_void_box(a: CaptureRoBox, var b: CaptureRoBox) raises Never:
    var total = a.value + b.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureRoBox(1)
    var b = CaptureRoBox(2)
    var result = Capture[Never].borrow(a).take(b^).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
def callback_error_value_box(a: CaptureRoBox, var b: CaptureRoBox) raises CaptureRoFault -> Int:
    var total = a.value + b.value
    raise CaptureRoFault(total)
def check_error_value_box() raises:
    var a = CaptureRoBox(1)
    var b = CaptureRoBox(2)
    var result = Capture[CaptureRoFault].borrow(a).take(b^).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRoFault]
    assert_equal(result._err().value.code, 3)
    assert_equal(a.value, 1)
def callback_error_void_box(a: CaptureRoBox, var b: CaptureRoBox) raises CaptureRoFault:
    var total = a.value + b.value
    raise CaptureRoFault(total)
def check_error_void_box() raises:
    var a = CaptureRoBox(1)
    var b = CaptureRoBox(2)
    var result = Capture[CaptureRoFault].borrow(a).take(b^).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRoFault]
    assert_equal(result._err().value.code, 3)
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
