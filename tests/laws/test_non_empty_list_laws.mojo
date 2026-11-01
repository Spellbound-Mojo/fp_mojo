"""Non-empty concatenation is associative; mapping preserves identity/composition."""
from fp.data import NonEmptyList
from fp.algebra import NonEmptyListSemigroup, NonEmptyListFamily, map
from std.testing import assert_equal

def nel_law_id(x: Int) -> Int: return x
def nel_law_add(x: Int) -> Int: return x + 1
def nel_law_mul(x: Int) -> Int: return x * 2
def nel_law_both(x: Int) -> Int: return (x + 1) * 2

def main() raises:
    comptime S = NonEmptyListSemigroup[Int]
    for n in range(1, 6):
        var a = NonEmptyList(n, List[Int]([n + 1]))
        var b = NonEmptyList(n + 2)
        var c = NonEmptyList(n + 3, List[Int]([n + 4]))
        var ab = S.combine(a.copy(), b.copy())
        var left = S.combine(ab^, c.copy())
        var bc = S.combine(b^, c^)
        var right = S.combine(a.copy(), bc^)
        assert_equal(left^.into_list(), right^.into_list())
        var same = map[NonEmptyListFamily](a.copy(), nel_law_id)
        assert_equal(same^.into_list(), a.copy().into_list())
        var first = map[NonEmptyListFamily](a.copy(), nel_law_add)
        var composed = map[NonEmptyListFamily](first^, nel_law_mul)
        var direct = map[NonEmptyListFamily](a^, nel_law_both)
        assert_equal(composed^.into_list(), direct^.into_list())
    print("non-empty list laws: ok")
