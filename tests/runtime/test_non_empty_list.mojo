"""Non-empty storage, shape preservation, filtering and validation policies."""
from fp.data import NonEmptyList, Result, Ok, Err
from fp.algebra import (NonEmptyListFamily, NonEmptyListSemigroup, ValidationFamily,
                        ResultFamily, OptionalFamily, ListFamily, IdentityFamily,
                        map, traverse, filter, filter_map)
from fp.functions import piped
from fp.iteration import iterated
from std.testing import assert_equal, assert_true, assert_false


def nel_twice(value: Int) -> Int: return value * 2
def nel_false(value: Int) -> Bool: return False
def nel_even(value: Int) -> Optional[Int]:
    if value % 2 == 0: return Optional(value)
    return None
def nel_check(value: Int) -> Result[Int, NonEmptyList[Int]]:
    if value < 0: return Err(NonEmptyList(value))
    return Ok(value * 2)
def nel_choices(value: Int) -> List[Int]: return [value, -value]
def nel_add(a: Int, b: Int) -> Int: return a + b


def main() raises:
    assert_false(NonEmptyList[Int].from_list(List[Int]()))
    var rejected = False
    try:
        _ = NonEmptyList[Int](values=List[Int]())
    except error:
        rejected = True
        assert_equal(String(error), "NonEmptyList requires at least one element")
    assert_true(rejected)
    var checked = NonEmptyList[Int].from_list(List[Int]([1, 2, 3]))
    assert_true(Bool(checked))
    var source = checked.unsafe_take()
    assert_equal(len(source), 3)
    assert_equal(source.first(), 1)
    source.first() = 7
    assert_equal(source^.into_list(), [7, 2, 3])
    assert_equal(NonEmptyList(9).into_list(), [9])
    var nested = NonEmptyList(List[Int]())
    comptime assert type_of(nested) == NonEmptyList[List[Int]]
    assert_equal(len(nested), 1)
    assert_equal(len(nested.first()), 0)
    assert_equal(iterated(NonEmptyList(1, List[Int]([2, 3]))).collect_list(), [1, 2, 3])
    var mapped = map[NonEmptyListFamily](NonEmptyList(1, List[Int]([2, 3])), nel_twice)
    assert_equal(mapped^.into_list(), [2, 4, 6])
    var identity = traverse[NonEmptyListFamily, IdentityFamily](NonEmptyList(4), nel_twice)
    assert_equal(identity^.into_list(), [8])
    assert_equal(filter[NonEmptyListFamily](NonEmptyList(1), nel_false), List[Int]())
    assert_equal(filter_map[NonEmptyListFamily](NonEmptyList(1, List[Int]([2, 3, 4])), nel_even), [2, 4])
    var absent = traverse[NonEmptyListFamily, OptionalFamily](NonEmptyList(1, List[Int]([2])), nel_even)
    assert_false(absent)
    var present = traverse[NonEmptyListFamily, OptionalFamily](NonEmptyList(2, List[Int]([4])), nel_even)
    var values = present.unsafe_take()
    assert_equal(values^.into_list(), [2, 4])
    var ordinary = traverse[NonEmptyListFamily, ResultFamily[NonEmptyList[Int]]](NonEmptyList(-1, List[Int]([-2])), nel_check)
    assert_equal(ordinary^._take_err().into_list(), [-1])
    comptime Accumulate = ValidationFamily[NonEmptyListSemigroup[Int]]
    var invalid = traverse[NonEmptyListFamily, Accumulate](NonEmptyList(-1, List[Int]([2, -3])), nel_check)
    assert_equal(invalid^._take_err().into_list(), [-1, -3])
    var valid = traverse[NonEmptyListFamily, Accumulate](NonEmptyList(1, List[Int]([2])), nel_check)
    assert_equal(valid^._take_ok().into_list(), [2, 4])
    var pair = piped(nel_check(-1)).par_map_n[NonEmptyListSemigroup[Int]]((nel_check(-2),), nel_add).get()
    assert_equal(pair^._take_err().into_list(), [-1, -2])
    var branches = traverse[NonEmptyListFamily, ListFamily](NonEmptyList(1, List[Int]([2])), nel_choices)
    var expected = List[List[Int]]([List[Int]([1, 2]), List[Int]([1, -2]), List[Int]([-1, 2]), List[Int]([-1, -2])])
    assert_equal(len(branches), 4)
    for i in range(4):
        assert_equal(branches[i].copy().into_list(), expected[i])
    print("non-empty list: ok")
