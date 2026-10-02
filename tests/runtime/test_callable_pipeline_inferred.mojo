"""Inferred type paths: heterogeneous values, state, wide packs and overload compatibility."""
from fp.functions import pipe, as_unary
from fp.data import Result, Err
from std.testing import assert_equal

def increment(var value: Int) -> Int: return value + 1
def label(var value: Int) -> String: return String(value)
def size(value: String) -> Int: return value.byte_length()
def pair(var value: Int) -> Tuple[Int, String]: return (value, String("tuple"))
def whole(value: Tuple[Int, String]) -> Int: return value[0] + value[1].byte_length()
def failure_value(var value: Int) -> Result[Int, String]:
    return Result[Int, String](Err(String(value)))
def inspect(value: Result[Int, String]) -> Int: return Int(value.is_err())
def explicit_never(var value: Int) raises Never -> Int: return value * 2


def main() raises:
    var add = as_unary(increment)
    var text = as_unary(label)
    var length = as_unary(size)
    var tuple_stage = as_unary(pair)
    var tuple_whole = as_unary(whole)
    var result_stage = as_unary(failure_value)
    var result_whole = as_unary(inspect)
    var doubled = as_unary(explicit_never)
    # Literal and String inputs, then type-changing stages; no expected result annotation.
    assert_equal(pipe(98, add, text, length), size(label(increment(98))))
    assert_equal(pipe(String("word"), length, add), 5)
    assert_equal(pipe(7, tuple_stage, tuple_whole), 12)
    assert_equal(pipe(7, result_stage, result_whole), 1)
    assert_equal(pipe(3, doubled, add), 7)
    assert_equal(pipe(0, add, add, add, add, add, add, add, add,
                         add, add, add, add, add, add, add, add), 16)
    var calls = 0
    def counter(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + calls
    var counted = as_unary(counter)
    assert_equal(calls, 0)
    assert_equal(pipe(0, counted, add), 2)
    assert_equal(pipe(0, counted, add), 3)
    assert_equal(calls, 2)
    # Existing zero/one-stage overloads keep native inference and unpromoted input.
    assert_equal(pipe(4), 4)
    assert_equal(pipe(4, increment), 5)
