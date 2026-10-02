"""Explicit type paths, whole values, native state and unchanged simple calls."""
from fp.functions import identity, pipe, as_unary
from fp.data import Result, Err
from std.builtin.variadics import TypeList
from std.testing import assert_equal

def increment(var value: Int) -> Int: return value + 1
def text(var value: Int) -> String: return String(value)
def size(value: String) -> Int: return value.byte_length()
def pair(var value: Int) -> Tuple[Int, String]: return (value, String("tuple"))
def whole(value: Tuple[Int, String]) -> Int: return value[0] + value[1].byte_length()
def error_value(var value: Int) -> Result[Int, String]:
    return Result[Int, String](Err(String(value)))
def inspect(value: Result[Int, String]) -> Int: return Int(value.is_err())

@fieldwise_init
struct Failure(Copyable):
    var code: Int

def fail(var value: Int) raises Failure -> Int:
    raise Failure(value)
def never(var value: Int) raises Never -> Int: return value * 2

def main() raises:
    comptime Empty = TypeList.of[Trait=Movable & Deinitable]()
    comptime One = TypeList.of[Trait=Movable & Deinitable, Int]()
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int, String, Int]()
    assert_equal(pipe[Empty](7), 7)
    assert_equal(pipe(7), 7)
    var add = as_unary(increment)
    var label = as_unary(text)
    var length = as_unary(size)
    assert_equal(pipe[One](7, add), pipe(7, increment))
    assert_equal(pipe[Path](98, add, label, length), size(text(increment(98))))
    comptime Wide = TypeList.splat[Trait=Movable & Deinitable, 16, Int]()
    assert_equal(pipe[Wide](0, add, add, add, add, add, add, add, add,
                           add, add, add, add, add, add, add, add), 16)
    var calls = 0
    def counter(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + calls
    var counted = as_unary(counter)
    comptime Two = TypeList.of[Trait=Movable & Deinitable, Int, Int]()
    assert_equal(calls, 0)
    assert_equal(pipe[Two](0, counted, add), 2)
    assert_equal(pipe[Two](0, counted, add), 3)
    assert_equal(calls, 2)
    var tuple_stage = as_unary(pair)
    var tuple_whole = as_unary(whole)
    comptime TuplePath = TypeList.of[Trait=Movable & Deinitable, Tuple[Int, String], Int]()
    assert_equal(pipe[TuplePath](7, tuple_stage, tuple_whole), 12)
    var result_stage = as_unary(error_value)
    var result_whole = as_unary(inspect)
    comptime ResultPath = TypeList.of[Trait=Movable & Deinitable, Result[Int, String], Int]()
    assert_equal(pipe[ResultPath](7, result_stage, result_whole), 1)
    var doubled = as_unary(never)
    assert_equal(pipe[Two](3, doubled, add), 7)
    var rejected = as_unary(fail)
    var caught = False
    try: _ = pipe[Two, Failure](42, rejected, counted)
    except error:
        caught = True
        assert_equal(error.code, 42)
    assert_equal(caught, True)
    assert_equal(calls, 2)
    # Existing generic identity remains a normal immediate native application.
    assert_equal(identity(pipe(4, increment)), 5)
