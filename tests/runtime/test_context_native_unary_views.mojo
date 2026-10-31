"""Stored native adapters share the same admission as reusable unary chains."""
from fp.functions import pipeline, as_unary
from fp.algebra import map as algebra_map, OptionalFamily
from fp.data import Result, Ok, Err, ok, err
from fp.effects import Reader, run
from std.testing import assert_equal, assert_true


def double(var value: Int) -> Int: return value * 2
def triple(var value: Int) -> Int: return value * 3
def optional(var value: Int) -> Optional[Int]: return Optional(value + 1)
def checked(var value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative"))
    return Ok(value + 1)
def throwing(var value: Int) raises Int -> Int: raise value

def main() raises:
    var pointer: def(var Int) thin -> Int = double
    var transform = as_unary(pointer)
    pointer = triple
    assert_equal(pointer(4), 12)
    assert_equal(pipeline(Optional(4)).map(transform).get_or(0), 8)
    assert_equal(pipeline(5).then(transform).get(), 10)
    assert_equal(algebra_map[OptionalFamily](Optional(3), transform).value(), 6)
    assert_equal(pipeline(Optional(4)).map(transform).get().value(), 8)
    assert_equal(ok[Never](6).map(transform).raise_on_err(), 12)
    assert_equal(err[Int](2).value_or(transform), 4)
    assert_equal(pipeline(err[Int](3)).fold_owned(transform, transform), 6)
    var selected = as_unary(optional)
    assert_equal(pipeline[Int]([1, 2]).traverse(selected).get().value(), [2, 3])
    assert_equal(pipeline(Optional(3)).flat_map(selected).get_or(0), 4)
    assert_equal(pipeline(4).then(selected).map(transform).get_or(0), 10)
    var validated = as_unary(checked)
    var gathered = pipeline[Int]([1, 2]).traverse(validated).get()
    comptime assert type_of(gathered) == Result[List[Int], String]
    assert_equal(gathered^.raise_on_err(), [2, 3])
    assert_true(pipeline(-1).then(validated).get().is_err())

    var failure = as_unary(throwing)
    var caught = False
    try: _ = pipeline(4).raising[String]().then(failure).get()
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 4)
        caught = True
    assert_true(caught)
    var calls = 0
    def observe(var value: Int) raises Never {mut calls}: calls += value
    var observer = as_unary(observe)
    _ = pipeline(2).then(observer).get()
    _ = pipeline(3).then(observer).get()
    assert_equal(calls, 5)
    assert_equal(pipeline(7).then(transform^).get(), 14)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(5)).map(as_unary(double)).get()
    assert_equal(run[Reader[Int]](pending^, 0), 10)
