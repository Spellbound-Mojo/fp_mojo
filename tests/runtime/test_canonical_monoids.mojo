from fp.functions import pipeline
from fp.iteration import iterated, fold_map, combine_all, fold_map_effect
from fp.algebra import OptionalFamily
from fp.algebra import StringMonoid, IntSumMonoid
from std.testing import assert_equal
def show(var value: Int) -> String: return "#" + String(value)
def pair(var value: Int) -> List[Int]: return List[Int]([value, value])
def maybe(var value: Int) -> Optional[String]:
    if value < 0: return None
    return String(value)
def checked(var value: Int) raises Int -> String:
    if value < 0: raise value
    return String(value)
def main() raises:
    # String and List select concatenation; no monoid is named.
    assert_equal(fold_map(range(3), show), "#0#1#2")
    assert_equal(fold_map(range(0), show), "")
    assert_equal(fold_map(range(2), pair), List[Int]([0, 0, 1, 1]))
    assert_equal(combine_all(List[String](["a", "b"])), "ab")
    assert_equal(combine_all(List[List[Int]]([List[Int]([1]), List[Int]([2, 3])])), List[Int]([1, 2, 3]))
    assert_equal(iterated(range(3)).fold_map(show), "#0#1#2")
    assert_equal(iterated(List[String](["x", "y"])).combine_all(), "xy")
    assert_equal(pipeline(List[Int]([0, 1])).fold_map(show).get(), "#0#1")
    assert_equal(pipeline(List[String](["p", "q"])).combine_all().get(), "pq")
    assert_equal(pipeline(range(3)).fold_map(show).get(), "#0#1#2")
    assert_equal(pipeline(List[String](["m", "n"])).combine_all().get(), "mn")
    var prefix = String(">")
    def tagged(var value: Int) {imm prefix} -> String: return prefix + String(value)
    assert_equal(fold_map(range(2), tagged), ">0>1")
    assert_equal(pipeline(range(2)).fold_map(tagged).get(), ">0>1")
    assert_equal(pipeline(range(2)).fold_map(checked).get(), "01")
    # Effectful folds combine the effect's payload the same way.
    assert_equal(fold_map_effect(range(3), maybe).value(), "012")
    assert_equal(fold_map_effect[StringMonoid](range(2), maybe).value(), "01")
    assert_equal(fold_map_effect[StringMonoid, OptionalFamily](range(2), maybe).value(), "01")
    assert_equal(iterated(range(2)).fold_map_effect(maybe).value(), "01")
    assert_equal(pipeline(List[Int]([1, 2])).fold_map_effect(maybe).get().value(), "12")
    assert_equal(pipeline(range(3)).fold_map_effect(maybe).get().value(), "012")
    assert_equal(pipeline(range(2)).fold_map_effect[J=OptionalFamily](maybe).get().value(), "01")
    assert_equal(pipeline(List[Optional[String]]([Optional(String("a")), Optional(String("b"))])).combine_all_effect().get().value(), "ab")
    assert_equal(pipeline(List[Optional[String]]([Optional(String("a"))])).combine_all_effect[J=OptionalFamily]().get().value(), "a")
    # Explicit monoids still bind, including numbers.
    assert_equal(fold_map[StringMonoid](range(2), show), "#0#1")
    assert_equal(combine_all[IntSumMonoid](List[Int]([1, 2, 3])), 6)
    assert_equal(pipeline(List[Int]([1, 2])).combine_all[IntSumMonoid]().get(), 3)
