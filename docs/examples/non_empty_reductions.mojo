from fp.data import NonEmptyList
from fp.algebra import NonEmptyListSemigroup, StringMonoid
from fp.iteration import reduce_non_empty, reduce_map, combine_non_empty, minimum_by_non_empty
from std.testing import assert_equal

def subtract(var total: Int, var value: Int) -> Int: return total - value

def label(var value: Int) -> String: return String(value)

def length(value: String) -> Int: return value.byte_length()

def main() raises:
    var reduced = reduce_non_empty(subtract, NonEmptyList(10, [2, 3]))
    assert_equal(reduced, 5)
    print("reduced:", reduced)
    print("labels:", reduce_map[StringMonoid](label, NonEmptyList(1, [2, 3])))
    var groups = NonEmptyList(NonEmptyList(1), [NonEmptyList(2), NonEmptyList(3)])
    var joined = combine_non_empty[NonEmptyListSemigroup[Int]](groups^)
    assert_equal(joined^.into_list(), [1, 2, 3])
    var shortest = minimum_by_non_empty(length, NonEmptyList(String("alpha"), [String("b"), String("c")]))
    print("shortest:", shortest)
