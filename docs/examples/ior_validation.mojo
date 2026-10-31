"""Keep successful values with warnings and collect independent diagnostics."""
from fp.data import Ior, Left, Right, Both, NonEmptyList
from fp.algebra import IorFamily, IorValidationFamily, NonEmptyListSemigroup, ListFamily, traverse
from fp.functions import piped
from std.testing import assert_equal

comptime Issues = NonEmptyList[String]
comptime Checked = Ior[Issues, Int]
comptime Sequential = IorFamily[NonEmptyListSemigroup[String]]
comptime Accumulating = IorValidationFamily[NonEmptyListSemigroup[String]]

def checked(value: Int) -> Checked:
    if value < 0: return Left(Issues(String(value) + " is negative"))
    if value == 0: return Both(Issues(String("zero accepted")), value)
    return Right(value)

def twice(value: Int) -> Int: return value * 2

def main() raises:
    var accepted = piped(checked(0)).map[Sequential](twice).get()
    assert_equal(accepted[Both[Issues, Int]].right, 0)
    print("value:", accepted[Both[Issues, Int]].right)
    print("warning:", accepted[Both[Issues, Int]].left.first())
    var all_issues = traverse[Accumulating, ListFamily](List[Int]([0, -2, -3]), checked)
    var first_failure = traverse[Sequential, ListFamily](List[Int]([0, -2, -3]), checked)
    assert_equal(len(all_issues[Left[Issues]].value), 3)
    assert_equal(len(first_failure[Left[Issues]].value), 2)
    print("independent diagnostics:", len(all_issues[Left[Issues]].value))
    print("sequential diagnostics:", len(first_failure[Left[Issues]].value))
