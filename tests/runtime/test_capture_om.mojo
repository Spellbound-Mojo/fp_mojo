from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOmFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOmBox(Movable):
    var value: Int
def callback_pure_value_scalar(var a: Int, mut b: Int) -> Int:
    b += 10
    var total = a + b
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).mutable(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(b, 12)
def callback_pure_void_scalar(var a: Int, mut b: Int):
    b += 10
    var total = a + b
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).mutable(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b, 12)
def callback_never_value_scalar(var a: Int, mut b: Int) raises Never -> Int:
    b += 10
    var total = a + b
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).mutable(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(b, 12)
def callback_never_void_scalar(var a: Int, mut b: Int) raises Never:
    b += 10
    var total = a + b
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).mutable(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b, 12)
def callback_error_value_scalar(var a: Int, mut b: Int) raises CaptureOmFault -> Int:
    b += 10
    var total = a + b
    raise CaptureOmFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOmFault].take(a).mutable(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOmFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(b, 12)
def callback_error_void_scalar(var a: Int, mut b: Int) raises CaptureOmFault:
    b += 10
    var total = a + b
    raise CaptureOmFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOmFault].take(a).mutable(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOmFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(b, 12)
def callback_pure_value_box(var a: CaptureOmBox, mut b: CaptureOmBox) -> Int:
    b.value += 10
    var total = a.value + b.value
    return total
def check_pure_value_box() raises:
    var a = CaptureOmBox(1)
    var b = CaptureOmBox(2)
    var result = Capture[Never].take(a^).mutable(b).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(b.value, 12)
def callback_pure_void_box(var a: CaptureOmBox, mut b: CaptureOmBox):
    b.value += 10
    var total = a.value + b.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureOmBox(1)
    var b = CaptureOmBox(2)
    var result = Capture[Never].take(a^).mutable(b).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 12)
def callback_never_value_box(var a: CaptureOmBox, mut b: CaptureOmBox) raises Never -> Int:
    b.value += 10
    var total = a.value + b.value
    return total
def check_never_value_box() raises:
    var a = CaptureOmBox(1)
    var b = CaptureOmBox(2)
    var result = Capture[Never].take(a^).mutable(b).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(b.value, 12)
def callback_never_void_box(var a: CaptureOmBox, mut b: CaptureOmBox) raises Never:
    b.value += 10
    var total = a.value + b.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureOmBox(1)
    var b = CaptureOmBox(2)
    var result = Capture[Never].take(a^).mutable(b).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 12)
def callback_error_value_box(var a: CaptureOmBox, mut b: CaptureOmBox) raises CaptureOmFault -> Int:
    b.value += 10
    var total = a.value + b.value
    raise CaptureOmFault(total)
def check_error_value_box() raises:
    var a = CaptureOmBox(1)
    var b = CaptureOmBox(2)
    var result = Capture[CaptureOmFault].take(a^).mutable(b).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOmFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(b.value, 12)
def callback_error_void_box(var a: CaptureOmBox, mut b: CaptureOmBox) raises CaptureOmFault:
    b.value += 10
    var total = a.value + b.value
    raise CaptureOmFault(total)
def check_error_void_box() raises:
    var a = CaptureOmBox(1)
    var b = CaptureOmBox(2)
    var result = Capture[CaptureOmFault].take(a^).mutable(b).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOmFault]
    assert_equal(result._err().value.code, 13)
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
