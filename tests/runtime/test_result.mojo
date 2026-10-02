from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true


def double(var value: Int) -> Int:
    return value * 2


def positive(value: Int) -> Int:
    return value


def negative(error: Int) -> Int:
    return -error


def checked(var value: Int) -> Result[Int, Int]:
    if value > 0:
        return Result[Int, Int](Ok(value))
    return Result[Int, Int](Err(7))


def main() raises:
    var ok = Result[Int, Int](Ok(21))
    var err = Result[Int, Int](Err(21))
    assert_equal(ok.fold(positive, negative), 21)
    assert_equal(err.fold(positive, negative), -21)
    var mapped = map[ResultFamily[type_of(ok).Error]](double, ok^)
    assert_equal(mapped.fold(positive, negative), 42)
    var calls = 0
    def track(var value: Int) {mut calls} -> Int:
        calls += 1
        return value * 10
    var unchanged = map[ResultFamily[type_of(err).Error]](track, err^)
    assert_true(unchanged.is_err())
    assert_equal(calls, 0)
    var rebound = flat_map[ResultFamily[type_of(mapped).Error]](checked, mapped^)
    assert_equal(rebound.fold(positive, negative), 42)
    var remapped = unchanged^.map_err(double)
    assert_equal(remapped.fold(positive, negative), -42)
    var recovered = remapped^.or_else(checked)
    assert_true(recovered.is_ok())
