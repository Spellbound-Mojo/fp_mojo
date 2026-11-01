from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
@fieldwise_init
struct CaptureOrFault(Movable):
    var code: Int
@fieldwise_init
struct CaptureOrBox(Movable):
    var value: Int
def callback_pure_value_scalar(var a: Int, b: Int) -> Int:
    var total = a + b
    return total
def check_pure_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).borrow(b).run(callback_pure_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(b, 2)
def callback_pure_void_scalar(var a: Int, b: Int):
    var total = a + b
    _ = total
def check_pure_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).borrow(b).run(callback_pure_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b, 2)
def callback_never_value_scalar(var a: Int, b: Int) raises Never -> Int:
    var total = a + b
    return total
def check_never_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).borrow(b).run(callback_never_value_scalar)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(b, 2)
def callback_never_void_scalar(var a: Int, b: Int) raises Never:
    var total = a + b
    _ = total
def check_never_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[Never].take(a).borrow(b).run(callback_never_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b, 2)
def callback_error_value_scalar(var a: Int, b: Int) raises CaptureOrFault -> Int:
    var total = a + b
    raise CaptureOrFault(total)
def check_error_value_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOrFault].take(a).borrow(b).run(callback_error_value_scalar)
    comptime assert type_of(result) == Result[Int, CaptureOrFault]
    assert_equal(result._err().value.code, 3)
    assert_equal(b, 2)
def callback_error_void_scalar(var a: Int, b: Int) raises CaptureOrFault:
    var total = a + b
    raise CaptureOrFault(total)
def check_error_void_scalar() raises:
    var a = 1
    var b = 2
    var result = Capture[CaptureOrFault].take(a).borrow(b).run(callback_error_void_scalar)
    comptime assert type_of(result) == Result[type_of(None), CaptureOrFault]
    assert_equal(result._err().value.code, 3)
    assert_equal(b, 2)
def callback_pure_value_box(var a: CaptureOrBox, b: CaptureOrBox) -> Int:
    var total = a.value + b.value
    return total
def check_pure_value_box() raises:
    var a = CaptureOrBox(1)
    var b = CaptureOrBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_pure_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(b.value, 2)
def callback_pure_void_box(var a: CaptureOrBox, b: CaptureOrBox):
    var total = a.value + b.value
    _ = total
def check_pure_void_box() raises:
    var a = CaptureOrBox(1)
    var b = CaptureOrBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_pure_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def callback_never_value_box(var a: CaptureOrBox, b: CaptureOrBox) raises Never -> Int:
    var total = a.value + b.value
    return total
def check_never_value_box() raises:
    var a = CaptureOrBox(1)
    var b = CaptureOrBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_never_value_box)
    comptime assert type_of(result) == Result[Int, Never]
    assert_equal(result._ok().value, 3)
    assert_equal(b.value, 2)
def callback_never_void_box(var a: CaptureOrBox, b: CaptureOrBox) raises Never:
    var total = a.value + b.value
    _ = total
def check_never_void_box() raises:
    var a = CaptureOrBox(1)
    var b = CaptureOrBox(2)
    var result = Capture[Never].take(a^).borrow(b).run(callback_never_void_box)
    comptime assert type_of(result) == Result[type_of(None), Never]
    assert_equal(result.is_ok(), True)
    assert_equal(b.value, 2)
def callback_error_value_box(var a: CaptureOrBox, b: CaptureOrBox) raises CaptureOrFault -> Int:
    var total = a.value + b.value
    raise CaptureOrFault(total)
def check_error_value_box() raises:
    var a = CaptureOrBox(1)
    var b = CaptureOrBox(2)
    var result = Capture[CaptureOrFault].take(a^).borrow(b).run(callback_error_value_box)
    comptime assert type_of(result) == Result[Int, CaptureOrFault]
    assert_equal(result._err().value.code, 3)
    assert_equal(b.value, 2)
def callback_error_void_box(var a: CaptureOrBox, b: CaptureOrBox) raises CaptureOrFault:
    var total = a.value + b.value
    raise CaptureOrFault(total)
def check_error_void_box() raises:
    var a = CaptureOrBox(1)
    var b = CaptureOrBox(2)
    var result = Capture[CaptureOrFault].take(a^).borrow(b).run(callback_error_void_box)
    comptime assert type_of(result) == Result[type_of(None), CaptureOrFault]
    assert_equal(result._err().value.code, 3)
    assert_equal(b.value, 2)
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
