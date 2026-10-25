from fp.functions import pipeline
from fp.data import Result, Ok
from std.testing import assert_equal
def main() raises:
    assert_equal(len(pipeline[Int](List[Int]([1])).get()), 1)
    assert_equal(pipeline[T=Int](Optional(3)).get().value(), 3)
    assert_equal(pipeline[T=Int, E=String](Result[Int, String](Ok(2))).get()._ok().value, 2)
