"""Combine independent Results and traverse effects without wrapper lambdas."""
from fp.data import Result, Ok, Err
from fp.functions import piped
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
    var combined = piped(Result[Int, String](Ok(3))).map2(Result[Int, String](Ok(4)), add).get()
    print("combined:", combined^.raise_on_err())
    var paired = piped(Result[Int, String](Ok(3))).product(Result[Int, String](Ok(4))).get()
    var pair = paired^.raise_on_err()
    print("paired:", pair[0], pair[1])
    var applied = piped(Optional(as_unary(twice))).ap(Optional(9)).get()
    var amount = applied.take()
    assert_equal(amount, 18)
    print("applied:", amount)
    var three = piped(Result[Int, String](Ok(3))).map_n(
        (Result[Int, String](Ok(4)), Result[Int, String](Ok(5))), add_three).get()
    print("combined three:", three^.raise_on_err())
    var tupled = piped(Optional(3)).product_n((Optional(4), Optional(5))).get()
    print("flat tuple:", tupled.value())
    var values: List[Int] = [1, 2, 3]
    var retained = piped(values^).traverse_tap[ResultFamily[String]](check).get()
    print("retained:", retained^.raise_on_err())
    var checked = iterated(range(3)).traverse_void[ResultFamily[String]](check)
    print("all checked:", checked.is_ok())
    var source_error = piped(Result[Int, String](Err(String("source error")))).traverse_void[ResultFamily[String]](check).get()
    print("source error preserved:", source_error^.raise_on_err().is_err())
