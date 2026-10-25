from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOBox(Movable):
    var value: Int
def callback_pure_value_scalar(var a: Int) -> Int:
    var total = a
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
def callback_pure_void_scalar(var a: Int):
    var total = a
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_scalar(var a: Int) raises Never -> Int:
    var total = a
    return total
def check_never_value_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
def callback_never_void_scalar(var a: Int) raises Never:
    var total = a
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var result = Capture[Never].take(a).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_scalar(var a: Int) raises CaptureOFault -> Int:
    var total = a
    raise CaptureOFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var result = Capture[CaptureOFault].take(a).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOFault]
    assert_equal(result._err().value.code, 1)
def callback_error_void_scalar(var a: Int) raises CaptureOFault:
    var total = a
    raise CaptureOFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var result = Capture[CaptureOFault].take(a).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOFault]
    assert_equal(result._err().value.code, 1)
def callback_pure_value_box(var a: CaptureOBox) -> Int:
    var total = a.value
    return total
def check_pure_value_box() raises:
    var a = CaptureOBox(1)
    var result = Capture[Never].take(a^).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
def callback_pure_void_box(var a: CaptureOBox):
    var total = a.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureOBox(1)
    var result = Capture[Never].take(a^).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_box(var a: CaptureOBox) raises Never -> Int:
    var total = a.value
    return total
def check_never_value_box() raises:
    var a = CaptureOBox(1)
    var result = Capture[Never].take(a^).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 1)
def callback_never_void_box(var a: CaptureOBox) raises Never:
    var total = a.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureOBox(1)
    var result = Capture[Never].take(a^).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_box(var a: CaptureOBox) raises CaptureOFault -> Int:
    var total = a.value
    raise CaptureOFault(total)
def check_error_value_box() raises:
    var a = CaptureOBox(1)
    var result = Capture[CaptureOFault].take(a^).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOFault]
    assert_equal(result._err().value.code, 1)
def callback_error_void_box(var a: CaptureOBox) raises CaptureOFault:
    var total = a.value
    raise CaptureOFault(total)
def check_error_void_box() raises:
    var a = CaptureOBox(1)
    var result = Capture[CaptureOFault].take(a^).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOFault]
    assert_equal(result._err().value.code, 1)
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
