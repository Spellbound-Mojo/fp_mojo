"""Accumulate a count and log together, and merge totals by key."""
from fp.algebra import ProductMonoid, IntSumMonoid, StringMonoid, DictMonoid
from fp.iteration import combine_all
from std.testing import assert_equal


def main() raises:
    comptime Report = ProductMonoid[IntSumMonoid, StringMonoid]
    var records: List[Tuple[Int, String]] = [(1, "a"), (1, "b"), (1, "c")]
    var report = combine_all[Report](records^)
    assert_equal(report[0], 3)
    assert_equal(report[1], "abc")
    print("report:", report[0], report[1])
    var first = Dict[String, Int]()
    first["apples"] = 2
    var second = Dict[String, Int]()
    second["apples"] = 3
    second["pears"] = 4
    var merged = DictMonoid[String, IntSumMonoid].combine(first^, second^)
    assert_equal(merged["apples"], 5)
    assert_equal(merged["pears"], 4)
    print("totals:", merged["apples"], merged["pears"])
