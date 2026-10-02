from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from fp.functions import identity
from std.testing import assert_equal


def read(value: Int) -> String:
    return String(value)


def read_error(error: String) -> String:
    return error.copy()


def equal(a: Result[Int, String], b: Result[Int, String]) raises:
    assert_equal(a.is_ok(), b.is_ok())
    assert_equal(a.fold(read, read_error), b.fold(read, read_error))


def id_int(var value: Int) -> Int:
    return identity(value)


def plus_one(var value: Int) -> Int:
    return value + 1


def triple(var value: Int) -> Int:
    return value * 3


def combined(var value: Int) -> Int:
    return triple(plus_one(value))


def pure(var value: Int) -> Result[Int, String]:
    return Result[Int, String](Ok(value))


def f(var value: Int) -> Result[Int, String]:
    if value < 0:
        return Result[Int, String](Err(String("negative")))
    return pure(value + 1)


def g(var value: Int) -> Result[Int, String]:
    return pure(value * 3)


def chained(var value: Int) -> Result[Int, String]:
    return flat_map[ResultFamily[type_of(f(value)).Error]](g, f(value))


def check_value(value: Int) raises:
    var r = pure(value)
    equal(map[ResultFamily[type_of(r.copy()).Error]](id_int, r.copy()), r)
    equal(map[ResultFamily[type_of(map[ResultFamily[type_of(r.copy()).Error]](plus_one, r.copy())).Error]](triple, map[ResultFamily[type_of(r.copy()).Error]](plus_one, r.copy())), map[ResultFamily[type_of(r.copy()).Error]](combined, r.copy()))
    equal(flat_map[ResultFamily[type_of(pure(value)).Error]](f, pure(value)), f(value))
    equal(flat_map[ResultFamily[type_of(r.copy()).Error]](pure, r.copy()), r)
    equal(flat_map[ResultFamily[type_of(flat_map[ResultFamily[type_of(r.copy()).Error]](f, r.copy())).Error]](g, flat_map[ResultFamily[type_of(r.copy()).Error]](f, r.copy())), flat_map[ResultFamily[type_of(r.copy()).Error]](chained, r.copy()))


def main() raises:
    # Representative pure, terminating callbacks; these are tests, not proofs.
    for value in range(-5, 6):
        check_value(value)
    var failed = Result[Int, String](Err(String("negative")))
    equal(map[ResultFamily[type_of(failed.copy()).Error]](id_int, failed.copy()), failed)
    equal(flat_map[ResultFamily[type_of(failed.copy()).Error]](pure, failed.copy()), failed)
    equal(flat_map[ResultFamily[type_of(flat_map[ResultFamily[type_of(failed.copy()).Error]](f, failed.copy())).Error]](g, flat_map[ResultFamily[type_of(failed.copy()).Error]](f, failed.copy())), flat_map[ResultFamily[type_of(failed.copy()).Error]](chained, failed.copy()))
