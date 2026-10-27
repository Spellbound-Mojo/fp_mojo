"""Flatten and filter effectful results with fluent traversal combinators."""
from fp.algebra import ResultFamily
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.iteration import iterated
from std.testing import assert_equal, assert_true


def expand(value: Int) -> Result[List[Int], String]:
    if value < 0: return Err(String("negative value"))
    var group: List[Int] = [value, value * 10]
    return Ok(group^)


def keep_even(value: Int) -> Result[Bool, String]:
    return Ok(value % 2 == 0)


def select_even(value: Int) -> Result[Optional[Int], String]:
    if value % 2 == 0: return Ok(Optional(value * 10))
    return Ok(Optional[Int]())


def main() raises:
    var values: List[Int] = [1, 2, 3]
    var expanded = pipeline(values.copy()).flat_traverse[ResultFamily[String]](expand).raise_on_err()
    var kept = pipeline(expanded^).filter_effect[ResultFamily[String]](keep_even).raise_on_err()
    assert_equal(kept, [10, 2, 20, 30])
    print("kept:", kept)

    var selected = iterated(values^).traverse_filter[ResultFamily[String]](select_even).raise_on_err()
    assert_equal(selected, [20])
    print("selected:", selected)

    var groups: List[Result[List[Int], String]] = [expand(1), expand(2)]
    var flattened = pipeline(groups^).flat_sequence[ResultFamily[String]]().raise_on_err()
    assert_equal(flattened, [1, 10, 2, 20])
    print("sequenced:", flattened)

    var checks: List[Result[Bool, String]] = [keep_even(1), keep_even(2)]
    var done = iterated(checks^).sequence_void[ResultFamily[String]]()
    assert_true(done.is_ok())
    print("effects succeeded:", done.is_ok())
