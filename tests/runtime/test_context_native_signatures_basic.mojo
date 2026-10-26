"""Stored thin pointers use the same selected admission as ordinary functions."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from std.testing import assert_equal

def increment(var value: Int) -> Int: return value + 1
def present(var value: Int) -> Optional[Int]: return Optional(value + 1)
def add(var first: Int, var second: Int) -> Int: return first + second
def positive(value: Int) -> Bool: return value > 0

def main() raises:
    var pointer: def(var Int) thin -> Int = increment
    var effect: def(var Int) thin -> Optional[Int] = present
    var binary: def(var Int, var Int) thin -> Int = add
    var predicate: def(Int) thin -> Bool = positive
    assert_equal(pipeline(1).then(pointer).get(), 2)
    assert_equal(pipeline(Optional(1)).map(pointer).get().value(), 2)
    assert_equal(pipeline(Optional(1)).flat_map(effect).get().value(), 2)
    assert_equal(pipeline(List[Int]([1])).traverse[OptionalFamily](effect).get().value(), List[Int]([2]))
    assert_equal(pipeline(Optional(1)).map2(Optional(2), binary).get().value(), 3)
    assert_equal(pipeline(List[Int]([1,2])).reduce_optional(binary).get().value(), 3)
    assert_equal(Bool(pipeline(List[Int]()).reduce_optional(binary).get()), False)
    assert_equal(pipeline(List[Int]([-1, 1])).filter(predicate).get(), List[Int]([1]))
    assert_equal(pipeline(List[Int]([-1, 1])).filter_not(predicate).get(), List[Int]([-1]))
