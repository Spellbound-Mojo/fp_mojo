"""Unary partial applications can be reused without copying their storage."""
from fp.functions import pipeline, partial
from fp.data import Result, Ok, Err, ok, err
from fp.effects import Reader, run
from std.testing import assert_equal, assert_true


def scale(factor: Int, value: Int) -> Int: return factor * value
def sum3(first: Int, second: Int, third: Int) -> Int: return first + second + third
def choose(offset: Int, value: Int) -> Optional[Int]: return Optional(value + offset)
def validate(offset: Int, value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative"))
    return Ok(value + offset)
def fail(offset: Int, value: Int) raises Int -> Int: raise value + offset


def main() raises:
    var triple = partial(scale, 3)
    assert_equal(pipeline(Optional(4)).map(triple).get_or(0), 12)
    assert_equal(pipeline(5).then(triple).get(), 15)
    assert_equal(ok[Never](6).map(triple).raise_on_err(), 18)
    assert_equal(err[Int](2).value_or(triple), 6)
    assert_equal(pipeline(err[Int](3)).fold_owned(triple, triple), 9)
    var selected = partial(choose, 2)
    assert_equal(pipeline(List[Int]([1, 2])).traverse(selected).get().value(), [3, 4])
    assert_equal(pipeline(Optional(3)).flat_map(selected).get_or(0), 5)
    assert_equal(pipeline(4).then(selected).map(triple).get_or(0), 18)
    var checked = partial(validate, 2)
    var gathered = pipeline(List[Int]([1, 2])).traverse(checked).get()
    comptime assert type_of(gathered) == Result[List[Int], String]
    assert_equal(gathered^.raise_on_err(), [3, 4])
    assert_true(pipeline(-1).then(checked).get().is_err())

    var raising = partial(fail, 7)
    var caught = False
    try: _ = pipeline(4).raising[String]().then(raising).get()
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 11)
        caught = True
    assert_true(caught)
    assert_equal(pipeline(7).then(triple^).get(), 21)

    var pending = pipeline[Reader[Int]](Reader[Int].pure(5)).map(partial(scale, 4)).get()
    assert_equal(run[Reader[Int]](pending^, 0), 20)
    var thunk = partial(scale, 3, 4)
    assert_equal(thunk(), 12)
    var binary = partial(sum3, 2)
    assert_equal(binary(3, 4), 9)
