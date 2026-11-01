"""Combine effects already in hand without a transformation callback."""
from fp.functions import pipeline
from fp.algebra import StringMonoid, ListMonoid
from std.testing import assert_equal

def main() raises:
    var fragments: List[Optional[String]] = [Optional(String("Hello ")), Optional(String("Mojo!"))]
    var message = pipeline(fragments^).combine_all_effect[StringMonoid]().get_or("")
    assert_equal(message, "Hello Mojo!")
    print(message)
    var groups = List[Optional[List[Int]]]()
    groups.append(Optional(List[Int]([1, 2])))
    groups.append(Optional(List[Int]([3])))
    var flattened = pipeline(groups^).combine_all_effect[ListMonoid[Int]]().get_or(List[Int]())
    assert_equal(flattened, List[Int]([1, 2, 3]))
    print("items:", flattened[0], flattened[1], flattened[2])
    var alternatives: List[List[String]] = [["a", "A"], ["b", "B"]]
    var choices = pipeline(alternatives^).combine_all_effect[StringMonoid]().get()
    assert_equal(choices, List[String](["ab", "aB", "Ab", "AB"]))
    print("choices:", choices[0], choices[1], choices[2], choices[3])
