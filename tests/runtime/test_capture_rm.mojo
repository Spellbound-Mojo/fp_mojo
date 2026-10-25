from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureRmFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureRmBox(Movable):
    var value: Int
def callback_pure_value_scalar(a: Int, mut b: Int) -> Int:
    b += 10
    var total = a + b
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_pure_void_scalar(a: Int, mut b: Int):
    b += 10
    var total = a + b
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_never_value_scalar(a: Int, mut b: Int) raises Never -> Int:
    b += 10
    var total = a + b
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_never_void_scalar(a: Int, mut b: Int) raises Never:
    b += 10
    var total = a + b
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_error_value_scalar(a: Int, mut b: Int) raises CaptureRmFault -> Int:
    b += 10
    var total = a + b
    raise CaptureRmFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRmFault].borrow(a).mutable(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureRmFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_error_void_scalar(a: Int, mut b: Int) raises CaptureRmFault:
    b += 10
    var total = a + b
    raise CaptureRmFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureRmFault].borrow(a).mutable(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureRmFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(a, 1)
    assert_equal(b, 12)
def callback_pure_value_box(a: CaptureRmBox, mut b: CaptureRmBox) -> Int:
    b.value += 10
    var total = a.value + b.value
    return total
def check_pure_value_box() raises:
    var a = CaptureRmBox(1)
    var b = CaptureRmBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_pure_void_box(a: CaptureRmBox, mut b: CaptureRmBox):
    b.value += 10
    var total = a.value + b.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureRmBox(1)
    var b = CaptureRmBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_never_value_box(a: CaptureRmBox, mut b: CaptureRmBox) raises Never -> Int:
    b.value += 10
    var total = a.value + b.value
    return total
def check_never_value_box() raises:
    var a = CaptureRmBox(1)
    var b = CaptureRmBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 13)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_never_void_box(a: CaptureRmBox, mut b: CaptureRmBox) raises Never:
    b.value += 10
    var total = a.value + b.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureRmBox(1)
    var b = CaptureRmBox(2)
    var result = Capture[Never].borrow(a).mutable(b).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_error_value_box(a: CaptureRmBox, mut b: CaptureRmBox) raises CaptureRmFault -> Int:
    b.value += 10
    var total = a.value + b.value
    raise CaptureRmFault(total)
def check_error_value_box() raises:
    var a = CaptureRmBox(1)
    var b = CaptureRmBox(2)
    var result = Capture[CaptureRmFault].borrow(a).mutable(b).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureRmFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(a.value, 1)
    assert_equal(b.value, 12)
def callback_error_void_box(a: CaptureRmBox, mut b: CaptureRmBox) raises CaptureRmFault:
    b.value += 10
    var total = a.value + b.value
    raise CaptureRmFault(total)
def check_error_void_box() raises:
    var a = CaptureRmBox(1)
    var b = CaptureRmBox(2)
    var result = Capture[CaptureRmFault].borrow(a).mutable(b).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureRmFault]
    assert_equal(result._err().value.code, 13)
    assert_equal(a.value, 1)
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
