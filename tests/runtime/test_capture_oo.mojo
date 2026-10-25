from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOoFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOoBox(Movable):
    var value: Int
def callback_pure_value_scalar(var a: Int, var b: Int) -> Int:
    var total = a + b
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_pure_void_scalar(var a: Int, var b: Int):
    var total = a + b
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_scalar(var a: Int, var b: Int) raises Never -> Int:
    var total = a + b
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_never_void_scalar(var a: Int, var b: Int) raises Never:
    var total = a + b
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).take(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_scalar(var a: Int, var b: Int) raises CaptureOoFault -> Int:
    var total = a + b
    raise CaptureOoFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOoFault].take(a).take(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOoFault]
    assert_equal(result._err().value.code, 3)
def callback_error_void_scalar(var a: Int, var b: Int) raises CaptureOoFault:
    var total = a + b
    raise CaptureOoFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOoFault].take(a).take(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOoFault]
    assert_equal(result._err().value.code, 3)
def callback_pure_value_box(var a: CaptureOoBox, var b: CaptureOoBox) -> Int:
    var total = a.value + b.value
    return total
def check_pure_value_box() raises:
    var a = CaptureOoBox(1)
    var b = CaptureOoBox(2)
    var result = Capture[Never].take(a^).take(b^).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_pure_void_box(var a: CaptureOoBox, var b: CaptureOoBox):
    var total = a.value + b.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureOoBox(1)
    var b = CaptureOoBox(2)
    var result = Capture[Never].take(a^).take(b^).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_never_value_box(var a: CaptureOoBox, var b: CaptureOoBox) raises Never -> Int:
    var total = a.value + b.value
    return total
def check_never_value_box() raises:
    var a = CaptureOoBox(1)
    var b = CaptureOoBox(2)
    var result = Capture[Never].take(a^).take(b^).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
def callback_never_void_box(var a: CaptureOoBox, var b: CaptureOoBox) raises Never:
    var total = a.value + b.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureOoBox(1)
    var b = CaptureOoBox(2)
    var result = Capture[Never].take(a^).take(b^).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
def callback_error_value_box(var a: CaptureOoBox, var b: CaptureOoBox) raises CaptureOoFault -> Int:
    var total = a.value + b.value
    raise CaptureOoFault(total)
def check_error_value_box() raises:
    var a = CaptureOoBox(1)
    var b = CaptureOoBox(2)
    var result = Capture[CaptureOoFault].take(a^).take(b^).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOoFault]
    assert_equal(result._err().value.code, 3)
def callback_error_void_box(var a: CaptureOoBox, var b: CaptureOoBox) raises CaptureOoFault:
    var total = a.value + b.value
    raise CaptureOoFault(total)
def check_error_void_box() raises:
    var a = CaptureOoBox(1)
    var b = CaptureOoBox(2)
    var result = Capture[CaptureOoFault].take(a^).take(b^).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOoFault]
    assert_equal(result._err().value.code, 3)
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
