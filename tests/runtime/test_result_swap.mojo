from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal

def describe(var error: String) -> Int: return error.byte_length()
def double(var value: Int) -> Int: return value * 2

def generic[T: Movable & Deinitable, E: Movable & Deinitable](var result: Result[T,E]) -> Result[E,T]:
    return result^.swap()

def main() raises:
    var success = Result[Int, String](Ok(7)).swap()
    comptime assert type_of(success) == Result[String, Int]
    assert_equal(success.is_err(), True)
    assert_equal(success._err().value, 7)
    var failure = Result[Int, String](Err(String("bad"))).swap()
    comptime assert type_of(failure) == Result[String, Int]
    assert_equal(failure.is_ok(), True)
    assert_equal(failure._ok().value, "bad")
    var restored = failure^.swap()
    assert_equal(restored.is_err(), True)
    assert_equal(restored._err().value, "bad")
    var same = Result[Int, Int](Err(11)).swap()
    assert_equal(same.is_ok(), True)
    assert_equal(same._ok().value, 11)
    var original = generic(Result[Int, String](Ok(9))).swap()
    assert_equal(original._ok().value, 9)
    var never = Result[Int, Never](Ok(5)).swap()
    comptime assert type_of(never) == Result[Never, Int]
    assert_equal(never._err().value, 5)

    # Mapping follows the former error channel; swapping back retains recovery.
    var mapped = pipeline(Result[Int, String](Err(String("bad")))).swap().map(describe).get()
    assert_equal(mapped._ok().value, 3)
    var rejected = pipeline(Result[Int, String](Ok(7))).swap().map(describe).map_err(double).get()
    assert_equal(rejected._err().value, 14)
    var extracted = pipeline(Result[Int, String](Err(String("bad")))).swap().to_optional()
    assert_equal(extracted.value(), "bad")
    var absent = pipeline(Result[Int, String](Ok(7))).swap().to_optional()
    assert_equal(Bool(absent), False)

    var calls = 0
    def checked(var error: String) raises Int {mut calls} -> Int:
        calls += 1
        raise error.byte_length()
    var caught = 0
    try:
        _ = pipeline(Result[Int, String](Err(String("bad")))).raising[Int]().swap().map(checked)
    except code: caught = code
    assert_equal(caught, 3)
    assert_equal(calls, 1)
    var skipped = pipeline(Result[Int, String](Ok(7))).raising[Int]().swap().map(checked).get()
    assert_equal(skipped._err().value, 7)
    assert_equal(calls, 1)
