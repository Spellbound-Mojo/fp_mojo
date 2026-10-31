from fp.functions import piped, pipeline
from fp.iteration import iterated, traverse
from fp.algebra import Accumulate
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true
def check(var value: Int) -> Result[Int, List[String]]:
    if value < 0: return Err(List[String](["negative " + String(value)]))
    return Ok(value * 10)
def main() raises:
    # Every error is collected in source order; no semigroup is named.
    var failed = traverse[Accumulate](List[Int]([1, -2, 3, -4]), check)
    assert_true(failed.is_err())
    assert_equal(failed._err().value, List[String](["negative -2", "negative -4"]))
    var passed = traverse[Accumulate](List[Int]([1, 2]), check)
    assert_equal(passed._ok().value, List[Int]([10, 20]))
    assert_equal(traverse[Accumulate](range(-2, 0), check)._err().value, List[String](["negative -2", "negative -1"]))
    assert_equal(iterated(List[Int]([-1, 2, -3])).traverse[Accumulate](check)._err().value, List[String](["negative -1", "negative -3"]))
    assert_equal(piped(List[Int]([-5, 6, -7])).traverse[Accumulate](check).get()._err().value, List[String](["negative -5", "negative -7"]))
    assert_equal(pipeline(List[Int]([-8, -9])).traverse[Accumulate](check).get()._err().value, List[String](["negative -8", "negative -9"]))
    var limit = 0
    def bounded(var value: Int) {imm limit} -> Result[Int, List[String]]:
        if value < limit: return Err(List[String]([String(value)]))
        return Ok(value)
    assert_equal(traverse[Accumulate](List[Int]([-1, 1, -2]), bounded)._err().value, List[String](["-1", "-2"]))
    # The default target still stops at the first error.
    assert_equal(traverse(List[Int]([1, -2, -4]), check)._err().value, List[String](["negative -2"]))
