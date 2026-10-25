from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureZeroFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureZeroBox(Movable):
    var value: Int
def callback_pure_value_scalar() -> Int:
    var total = 0
    return total
def check_pure_value_scalar() raises:
    var result = Capture[Never]().run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 0)
def callback_pure_void_scalar():
    var total = 0
    _ = total
def check_pure_void_scalar() raises:
    var result = Capture[Never]().run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_scalar() raises Never -> Int:
    var total = 0
    return total
def check_never_value_scalar() raises:
    var result = Capture[Never]().run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 0)
def callback_never_void_scalar() raises Never:
    var total = 0
    _ = total
def check_never_void_scalar() raises:
    var result = Capture[Never]().run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_scalar() raises CaptureZeroFault -> Int:
    var total = 0
    raise CaptureZeroFault(total)
def check_error_value_scalar() raises:
    var result = Capture[CaptureZeroFault]().run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureZeroFault]
    assert_equal(result._err().value.code, 0)
def callback_error_void_scalar() raises CaptureZeroFault:
    var total = 0
    raise CaptureZeroFault(total)
def check_error_void_scalar() raises:
    var result = Capture[CaptureZeroFault]().run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureZeroFault]
    assert_equal(result._err().value.code, 0)
def callback_pure_value_box() -> Int:
    var total = 0
    return total
def check_pure_value_box() raises:
    var result = Capture[Never]().run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 0)
def callback_pure_void_box():
    var total = 0
    _ = total
def check_pure_void_box() raises:
    var result = Capture[Never]().run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_box() raises Never -> Int:
    var total = 0
    return total
def check_never_value_box() raises:
    var result = Capture[Never]().run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 0)
def callback_never_void_box() raises Never:
    var total = 0
    _ = total
def check_never_void_box() raises:
    var result = Capture[Never]().run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_box() raises CaptureZeroFault -> Int:
    var total = 0
    raise CaptureZeroFault(total)
def check_error_value_box() raises:
    var result = Capture[CaptureZeroFault]().run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureZeroFault]
    assert_equal(result._err().value.code, 0)
def callback_error_void_box() raises CaptureZeroFault:
    var total = 0
    raise CaptureZeroFault(total)
def check_error_void_box() raises:
    var result = Capture[CaptureZeroFault]().run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureZeroFault]
    assert_equal(result._err().value.code, 0)
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
