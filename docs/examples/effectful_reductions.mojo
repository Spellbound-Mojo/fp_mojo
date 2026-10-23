"""Fold, test, and choose effects through method chains."""
from fp.algebra import ResultFamily
from fp.data import Result, Ok, Err
from fp.functions import piped
from fp.iteration import iterated
from std.testing import assert_equal, assert_true


def checked_add(total: Int, value: Int) -> Result[Int, String]:
    if value < 0:
        return Err(String("negative value"))
    return Ok(total + value)


def is_large(value: Int) -> Result[Bool, String]: return Ok(value > 5)
def is_positive(value: Int) -> Result[Bool, String]: return Ok(value > 0)
def large() -> Result[String, String]: return Ok(String("large value found"))
def small() -> Result[String, String]: return Ok(String("all values small"))


def main() raises:
    var values: List[Int] = [3, 5, 8]
    var total = (
        piped(values.copy())
        .fold_effect[ResultFamily[String]](checked_add, 0)
        .get()
        .raise_on_err()
    )
    var message = (
        piped(values.copy())
        .any_effect[ResultFamily[String]](is_large)
        .if_effect(large, small)
        .get()
        .raise_on_err()
    )
    var positive = iterated(values^).all_effect[ResultFamily[String]](is_positive).raise_on_err()
    var invalid: List[Int] = [3, -1, 8]
    var failed = iterated(invalid^).fold_effect[ResultFamily[String]](checked_add, 0)
    assert_equal(total, 16)
    assert_equal(message, "large value found")
    assert_true(positive)
    assert_true(failed.is_err())
    print("total:", total)
    print(message)
    print("all positive:", positive)
    print("negative input failed:", failed.is_err())
