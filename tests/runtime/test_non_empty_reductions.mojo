"""Guaranteed reductions need neither an identity nor an empty outcome."""
from fp.data import NonEmptyList
from fp.algebra import StringMonoid, NonEmptyListSemigroup
from fp.iteration import reduce_non_empty, reduce_map, combine_non_empty, minimum_by_non_empty, maximum_by_non_empty
from std.testing import assert_equal

def subtract(var left: Int, var right: Int) -> Int: return left - right

def as_text(var value: Int) -> String: return String(value)

def by_size(text: String) -> Int: return text.byte_length()

def main() raises:
    assert_equal(reduce_non_empty(NonEmptyList(10, [2, 3]), subtract), 5)
    assert_equal(reduce_non_empty(NonEmptyList(10), subtract), 10)
    assert_equal(reduce_map[StringMonoid](NonEmptyList(1, [2, 3]), as_text), "123")
    var groups = NonEmptyList(NonEmptyList(1), [NonEmptyList(2), NonEmptyList(3)])
    assert_equal(combine_non_empty[NonEmptyListSemigroup[Int]](groups^).into_list(), [1, 2, 3])
    assert_equal(minimum_by_non_empty(NonEmptyList(String("long"), [String("a"), String("b")]), by_size), "a")
    assert_equal(maximum_by_non_empty(NonEmptyList(String("first"), [String("other"), String("a")]), by_size), "first")
