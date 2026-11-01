"""Composed accumulation keeps identities, collision order and native carriers."""
from fp.algebra import (IntSumMonoid, IntProductMonoid, BoolAllMonoid, BoolAnyMonoid,
                        SIMDSumMonoid, ProductMonoid, OptionalMonoid, DictMonoid,
                        StringMonoid, ListMonoid, NonEmptyListSemigroup)
from fp.data import NonEmptyList
from fp.iteration import combine_all, sum
from fp.effects import Writer, tell, run_writer
from std.testing import assert_equal, assert_false


def main() raises:
    assert_equal(combine_all[IntSumMonoid]([1, 2, 3]), 6)
    assert_equal(combine_all[IntProductMonoid]([2, 3, 4]), 24)
    assert_equal(IntProductMonoid.empty(), 1)
    assert_equal(combine_all[BoolAllMonoid]([True, True, False]), False)
    assert_equal(combine_all[BoolAnyMonoid]([False, True, False]), True)
    assert_equal(BoolAllMonoid.empty(), True)
    assert_equal(BoolAnyMonoid.empty(), False)
    assert_equal(sum([1, 2, 3]), 6)
    comptime V = SIMDSumMonoid[DType.int32, 4]
    assert_equal(V.combine(V.Value(2), V.Value(3)), V.Value(5))
    comptime P = ProductMonoid[IntSumMonoid, StringMonoid]
    var first = P.combine((2, String("a")), (3, String("b")))
    assert_equal(first[0], 5)
    assert_equal(first[1], "ab")
    var identity = P.empty()
    assert_equal(identity[0], 0)
    assert_equal(identity[1], "")
    comptime Nested = ProductMonoid[P, BoolAllMonoid]
    var nested = Nested.combine(((2, String("a")), True), ((3, String("b")), False))
    assert_equal(nested[0][1], "ab")
    assert_false(nested[1])
    comptime O = OptionalMonoid[NonEmptyListSemigroup[Int]]
    var combined = O.combine(Optional(NonEmptyList(1)), Optional(NonEmptyList(2)))
    assert_equal(combined.take().into_list(), [1, 2])
    assert_false(O.empty())
    var alone = O.combine(O.empty(), Optional(NonEmptyList(3)))
    assert_equal(alone.take().into_list(), [3])
    comptime D = DictMonoid[String, StringMonoid]
    var left = Dict[String, String]()
    left["a"] = "left"
    left["b"] = "b"
    var right = Dict[String, String]()
    right["a"] = "right"
    right["c"] = "c"
    var merged = D.combine(left^, right^)
    assert_equal(len(merged), 3)
    assert_equal(merged["a"], "leftright")
    assert_equal(merged["b"], "b")
    assert_equal(merged["c"], "c")
    assert_equal(len(D.empty()), 0)
    var logged = run_writer[Writer[P]](tell[Writer[P]]((7, String("done"))))
    assert_equal(logged[0][0], 7)
    assert_equal(logged[0][1], "done")
