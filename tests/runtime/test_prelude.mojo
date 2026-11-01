"""The fp prelude re-exports everyday names from their packages."""
from fp import pipeline, iterated, Result, Ok, Err, Capture, map, filter, traverse, fold_map, combine_all, sum_by, Accumulate
from std.testing import assert_equal
def twice(var value: Int) -> Int: return value * 2
def positive(value: Int) -> Bool: return value > 0
def show(var value: Int) -> String: return String(value)
def check(var value: Int) -> Result[Int, List[String]]:
    if value < 0: return Err(List[String]([String(value)]))
    return Ok(value)
def main() raises:
    assert_equal(map(List[Int]([1, 2]), twice), List[Int]([2, 4]))
    assert_equal(filter(List[Int]([-1, 2]), positive), List[Int]([2]))
    assert_equal(pipeline(List[Int]([1, 2])).map(twice).get(), List[Int]([2, 4]))
    assert_equal(iterated(range(3)).map(twice).to_list(), List[Int]([0, 2, 4]))
    assert_equal(fold_map(range(3), show), "012")
    assert_equal(combine_all(List[String](["a", "b"])), "ab")
    assert_equal(sum_by(range(3), twice), 6)
    assert_equal(traverse[Accumulate](List[Int]([-1, 2, -3]), check)._err().value, List[String](["-1", "-3"]))
