from fp.data import Result, ok, err
from fp.functions import pipeline
from std.testing import assert_equal

def rc_double(value: Int) -> Int: return value * 2

def rc_forward[T: Movable & Deinitable, E: Movable & Deinitable](var value: T) -> Result[T, E]:
    return ok[E](value^)

def rc_error[T: Movable & Deinitable, E: Movable & Deinitable](var value: E) -> Result[T, E]:
    return err[T](value^)

def rc_pure() -> Int:
    return ok[Never](21)._ok().value + err[Never](21)._err().value

def main() raises:
    var value = ok[String](21)
    comptime assert type_of(value) == Result[Int, String]
    assert_equal(value.is_ok(), True)
    assert_equal(value._ok().value, 21)
    var failed = err[Int]("missing")
    comptime assert type_of(failed) == Result[Int, String]
    assert_equal(failed.is_err(), True)
    assert_equal(failed._err().value, "missing")
    var flag = ok[Int](True)
    comptime assert type_of(flag) == Result[Bool, Int]
    assert_equal(flag._ok().value, True)
    var values = ok[String](List[Int]([1,2]))
    comptime assert type_of(values) == Result[List[Int], String]
    assert_equal(values._ok().value, List[Int]([1,2]))
    assert_equal(pipeline(ok[String](21)).map(rc_double).get()._ok().value, 42)
    assert_equal(rc_forward[Int, String](7)._ok().value, 7)
    assert_equal(rc_error[Int, String](String("bad"))._err().value, "bad")
    assert_equal(rc_pure(), 42)
    var same_ok = ok[Int](7)
    var same_err = err[Int](7)
    assert_equal(same_ok.is_ok(), True)
    assert_equal(same_err.is_err(), True)
    var unit = ok[String](NoneType())
    comptime assert type_of(unit) == Result[NoneType, String]
    assert_equal(unit.is_ok(), True)
