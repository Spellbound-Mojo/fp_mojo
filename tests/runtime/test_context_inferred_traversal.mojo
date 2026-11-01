from fp.functions import pipeline
from fp.algebra import OptionalFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err, ok, err
from std.testing import assert_equal

def choices(var value: Int) -> List[Int]: return [value, value + 10]

def main() raises:
    var calls = 0
    def present(var value: Int) {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(value * 2) if value >= 0 else Optional[Int]()
    assert_equal(pipeline(List[Int]([1, 2])).traverse(present).get_or(List[Int]()), [2, 4])
    assert_equal(calls, 2)
    assert_equal(Bool(pipeline(List[Int]([1, -1, 2])).traverse(present).get()), False)
    assert_equal(calls, 4)
    var empty = pipeline(List[Int]()).traverse(present).get()
    assert_equal(Bool(empty), True)
    assert_equal(len(empty.value()), 0)
    assert_equal(calls, 4)
    # Existing positional family and callback-type bindings keep their meaning.
    assert_equal(pipeline(List[Int]([3])).traverse[OptionalFamily, type_of(present)](present).get_or(List[Int]()), [6])
    var combinations = pipeline(List[Int]([1, 2])).traverse(choices).get()
    var expected: List[List[Int]] = [[1, 2], [1, 12], [11, 2], [11, 12]]
    assert_equal(combinations, expected)

    calls = 0
    def validate(var value: Int) {mut calls} -> Result[Int, List[String]]:
        calls += 1
        if value < 0: return Err(List[String]([String(value)]))
        return Ok(value)
    var stopped = pipeline(List[Int]([1, -2, -3])).traverse(validate).swap().to_optional()
    assert_equal(stopped.value(), ["-2"])
    assert_equal(calls, 2)
    calls = 0
    var accumulated = pipeline(List[Int]([1, -2, -3])).traverse[ValidationFamily[ListMonoid[String]]](validate).swap().to_optional()
    assert_equal(accumulated.value(), ["-2", "-3"])
    assert_equal(calls, 3)

    var options = List[Optional[Int]]([Optional(1), Optional(2)])
    assert_equal(pipeline(options^).sequence().get_or(List[Int]()), [1, 2])
    var results = List[Result[Int, String]]([ok[String](1), ok[String](2)])
    assert_equal(pipeline(results^).sequence().get_or(List[Int]()), [1, 2])
    var failed = List[Result[Int, String]]([ok[String](1), err[Int]("bad"), ok[String](3)])
    assert_equal(pipeline(failed^).sequence().swap().get_or(""), "bad")
    var groups: List[List[Int]] = [[1, 11], [2, 12]]
    assert_equal(pipeline(groups^).sequence().get(), combinations)
    var one = pipeline(Optional(2)).traverse(validate).get_or(Optional[Int]())
    assert_equal(one.value(), 2)
    var original_error = pipeline(err[Int]("source")).traverse(present).get_or(err[Int]("empty"))
    assert_equal(original_error^.swap().get_or(""), "source")
