"""Traverse quantities with validation, or sequence results that already exist."""
from fp.algebra import traverse, sequence, ListFamily, OptionalFamily
from std.testing import assert_equal


def main() raises:
    var calls = 0

    def available(quantity: Int) {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(quantity) if 0 < quantity <= 5 else Optional[Int]()

    var quantities: List[Int] = [1, 3, 5]
    var accepted = traverse[ListFamily, OptionalFamily](available, quantities^)
    var expected: List[Int] = [1, 3, 5]
    assert_equal(accepted.value(), expected)
    assert_equal(calls, 3)
    print("traverse: items =", len(accepted.value()), "; calls =", calls)

    calls = 0
    var unavailable: List[Int] = [1, 8, 3]
    var rejected = traverse[ListFamily, OptionalFamily](available, unavailable^)
    assert_equal(Bool(rejected), False)
    assert_equal(calls, 2)
    print("failed traversal: present =", Bool(rejected), "; calls =", calls)

    # These results were computed before sequence was called.
    var results: List[Optional[Int]] = [Optional(1), Optional(3)]
    var gathered = sequence[ListFamily, OptionalFamily](results^)
    var expected_gathered: List[Int] = [1, 3]
    ref gathered_values = gathered.value()
    assert_equal(gathered_values, expected_gathered)
    print("sequence:", gathered_values[0], gathered_values[1])

    var missing: List[Optional[Int]] = [Optional(1), Optional[Int](), Optional(3)]
    assert_equal(Bool(sequence[ListFamily, OptionalFamily](missing^)), False)

    calls = 0
    var empty = List[Int]()
    var empty_result = traverse[ListFamily, OptionalFamily](available, empty^)
    assert_equal(Bool(empty_result), True)
    assert_equal(len(empty_result.value()), 0)
    assert_equal(calls, 0)
    print("empty traversal: present =", Bool(empty_result), "; items =", len(empty_result.value()))
