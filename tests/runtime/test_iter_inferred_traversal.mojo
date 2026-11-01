from fp.iteration import iterated
from fp.callables import as_unary
from fp.algebra import OptionalFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err, ok, err
from std.testing import assert_equal

def choices(var value: Int) -> List[Int]: return [value, value + 10]

def main() raises:
    var calls = 0
    def present(var value: Int) {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(value * 2) if value >= 0 else Optional[Int]()
    assert_equal(iterated(List[Int]([1, 2])).traverse(present).value(), [2, 4])
    assert_equal(calls, 2)
    assert_equal(Bool(iterated(List[Int]([1, -1, 2])).traverse(present)), False)
    assert_equal(calls, 4)
    var empty = iterated(List[Int]()).traverse(present)
    assert_equal(Bool(empty), True)
    assert_equal(len(empty.value()), 0)
    assert_equal(calls, 4)
    # Existing positional family and callback-type bindings keep their meaning.
    assert_equal(iterated(List[Int]([3])).traverse[OptionalFamily, type_of(present)](present).value(), [6])
    var combinations = iterated(List[Int]([1, 2])).traverse(choices)
    var expected: List[List[Int]] = [[1, 2], [1, 12], [11, 2], [11, 12]]
    assert_equal(combinations, expected)

    calls = 0
    def validate(var value: Int) {mut calls} -> Result[Int, List[String]]:
        calls += 1
        if value < 0: return Err(List[String]([String(value)]))
        return Ok(value)
    var stopped = iterated(List[Int]([1, -2, -3])).traverse(validate).swap().to_optional()
    assert_equal(stopped.value(), ["-2"])
    assert_equal(calls, 2)
    calls = 0
    var accumulated = iterated(List[Int]([1, -2, -3])).traverse[ValidationFamily[ListMonoid[String]]](validate).swap().to_optional()
    assert_equal(accumulated.value(), ["-2", "-3"])
    assert_equal(calls, 3)

    # Discarding success keeps the same target and short-circuit rule.
    calls = 0
    assert_equal(Bool(iterated(List[Int]([1, 2])).traverse_void(present)), True)
    assert_equal(calls, 2)
    assert_equal(Bool(iterated(List[Int]([1, -1, 2])).traverse_void(present)), False)
    assert_equal(calls, 4)
    assert_equal(Bool(iterated(List[Int]()).traverse_void(present)), True)
    assert_equal(calls, 4)
    assert_equal(len(iterated(List[Int]([1, 2])).traverse_void(choices)), 4)
    var discarded = iterated(List[Int]([-2, -3])).traverse_void(validate)
    assert_equal(discarded^.swap().raise_on_err(), ["-2"])
    var accumulated_void = iterated(List[Int]([-2, -3])).traverse_void[ValidationFamily[ListMonoid[String]]](validate)
    assert_equal(accumulated_void^.swap().raise_on_err(), ["-2", "-3"])

    # Legacy positional and named target/error bindings remain available.
    assert_equal(Bool(iterated(range(2)).traverse_void[OptionalFamily, type_of(present), Error](present)), True)
    assert_equal(Bool(iterated(range(2)).traverse_void[G=OptionalFamily, X=Error](present)), True)
    assert_equal(Bool(iterated(range(2)).traverse_void[X=Error](present)), True)
    var shared = as_unary(choices)
    assert_equal(iterated(List[Int]([1])).traverse(shared), [[1], [11]])
    assert_equal(iterated(List[Int]([2])).traverse(shared), [[2], [12]])
