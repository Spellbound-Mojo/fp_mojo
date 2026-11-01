from fp.data import Result, ok, err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct RCOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def rc_origins(owner: List[Int], other: List[Int]) raises:
    var value = Span(owner)
    var error = Span(other)
    comptime T = type_of(value)
    comptime E = type_of(error)
    var good = ok[E](value)
    comptime assert type_of(good) == Result[T, E]
    assert_equal(Pointer(to=good._ok().value[0]) == Pointer(to=owner[0]), True)
    var failed = err[T](error)
    comptime assert type_of(failed) == Result[T, E]
    assert_equal(Pointer(to=failed._err().value[0]) == Pointer(to=other[0]), True)

def main() raises:
    var drops = ArcPointer(0)
    var payload = RCOwner(7, drops)
    var success = ok[String](payload^)
    comptime assert type_of(success) == Result[RCOwner, String]
    assert_equal(success._ok().value.value, 7)
    assert_equal(drops[], 0)
    var extracted = success^.to_optional()
    assert_equal(extracted.value().value, 7)
    _ = extracted^
    assert_equal(drops[], 1)
    var failure = err[Int](RCOwner(9, drops))
    comptime assert type_of(failure) == Result[Int, RCOwner]
    assert_equal(failure._err().value.value, 9)
    assert_equal(drops[], 1)
    var error_value = pipeline(failure^).swap().to_optional()
    assert_equal(error_value.value().value, 9)
    _ = error_value^
    assert_equal(drops[], 2)
    var abandoned = ok[RCOwner](RCOwner(3, drops))
    _ = abandoned^
    assert_equal(drops[], 3)
    var abandoned_error = err[RCOwner](RCOwner(4, drops))
    _ = abandoned_error^
    assert_equal(drops[], 4)
    var a: List[Int] = [1]
    var b: List[Int] = [2]
    rc_origins(a, b)
