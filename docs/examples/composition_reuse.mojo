"""Reuse ordinary function chains across selected pipeline operations."""
from fp.functions import pipeline, flow, compose
from fp.data import Result, Ok, Err
from std.testing import assert_equal


def add_one(value: Int) -> Int: return value + 1
def double(value: Int) -> Int: return value * 2
def checked(value: Int) -> Result[String, String]:
    if value < 0: return Err(String("negative"))
    return Ok(String(value))


def main() raises:
    var transform = flow(add_one, double)
    var values: List[Int] = [1, 2]
    var mapped = pipeline(values^).map(transform).get()
    assert_equal(mapped, [4, 6])
    print("mapped:", mapped)
    print("reused:", pipeline(Optional(3)).map(transform).get_or(0))

    # compose runs right to left; this chain has the same meaning.
    var reversed = compose(double, add_one)
    assert_equal(pipeline(4).then(reversed).get(), 10)

    var validate = flow(add_one, checked)
    var inputs: List[Int] = [1, 2]
    var gathered = pipeline(inputs^).traverse(validate).raise_on_err()
    print("validated:", gathered[0], gathered[1])
    print("fallback:", pipeline(-2).then(validate).get_or(String("unavailable")))
