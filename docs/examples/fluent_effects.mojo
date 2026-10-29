"""Combine independent Results and traverse effects without wrapper lambdas."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.iteration import iterated
from fp.algebra import ResultFamily
from fp.callables import as_unary
from std.testing import assert_equal


def add(left: Int, right: Int) -> Int: return left + right
def add_three(a: Int, b: Int, c: Int) -> Int: return a + b + c
def twice(value: Int) -> Int: return value * 2


def check(value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative value"))
    return Ok(value * 10)


def main() raises:
    var combined = pipeline(Result[Int, String](Ok(3))).map2(Result[Int, String](Ok(4)), add).raise_on_err()
    print("combined:", combined)
    var pair = pipeline(Result[Int, String](Ok(3))).product(Result[Int, String](Ok(4))).raise_on_err()
    print("paired:", pair[0], pair[1])
    var applied = pipeline(Optional(as_unary(twice))).ap(Optional(9)).get()
    var amount = applied.take()
    assert_equal(amount, 18)
    print("applied:", amount)
    var three = pipeline(Result[Int, String](Ok(3))).map_n(
        (Result[Int, String](Ok(4)), Result[Int, String](Ok(5))), add_three).raise_on_err()
    print("combined three:", three)
    var tupled = pipeline(Optional(3)).product_n((Optional(4), Optional(5))).get()
    print("flat tuple:", tupled.value())
    var values: List[Int] = [1, 2, 3]
    var retained = pipeline(values^).traverse_tap(check).raise_on_err()
    print("retained:", retained)
    var checked = iterated(range(3)).traverse_void[ResultFamily[String]](check)
    print("all checked:", checked.is_ok())
    var source_error = pipeline(Result[Int, String](Err(String("source error")))).traverse_void(check).raise_on_err()
    print("source error preserved:", source_error.is_err())
