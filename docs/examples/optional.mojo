"""Match a standard Optional and a Result: the clauses borrow the stored value."""
import fp
from fp.data import Ok, Err, Result
from std.testing import assert_equal


def total(values: List[Int]) -> Int:
    var result = 0
    for value in values:
        result += value
    return result


def sum_or_missing(values: Optional[List[Int]]) -> Int:
    return fp.match(values,
        lambda (present: List[Int]) -> Int: total(present),
        lambda (absent: NoneType) -> Int: -1)


def describe(result: Result[Int, String]) -> String:
    return fp.match(result,
        fp.when[lambda (o: Ok[Int]) -> Bool: o.value > 40, lambda (o: Ok[Int]) -> String: "large"],
        lambda (o: Ok[Int]) -> String: "small",
        lambda (e: Err[String]) -> String: "failed: " + e.value)


def main() raises:
    var values: List[Int] = [10, 12, 20]
    var subject = Optional(values^)
    var result = sum_or_missing(subject)
    assert_equal(result, 42)
    # The match borrowed the list; it is still there.
    assert_equal(len(subject.value()), 3)
    assert_equal(sum_or_missing(None), -1)
    assert_equal(describe(Ok(result)), "large")
    assert_equal(describe(Ok(7)), "small")
    assert_equal(describe(Err(String("no data"))), "failed: no data")
    print("optional total =", result)
