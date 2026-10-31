"""Stateful filters preserve native container settings, keys and output families."""
from std.collections import Deque, LinkedList, StringDict
from std.hash import default_comp_time_hasher
from fp.functions import pipeline, pipeline_values
from fp.iteration import collect_list
from fp.data import NonEmptyList
from fp.algebra import NonEmptyListFamily
from fp.callables import mut_ref
from test_family_filter_mutable import EveryOther
from std.testing import assert_equal


def main() raises:
    var predicate = EveryOther(0)
    var deque = Deque[Int](capacity=8, min_capacity=4, maxlen=4, shrink=False)
    var linked = LinkedList[Int]()
    for value in range(4):
        deque.append(value)
        linked.append(value)
    var kept = pipeline(deque^).elements().filter(mut_ref(predicate)).get()
    comptime assert type_of(kept) == Deque[Int]
    assert_equal(kept._min_capacity, 4)
    assert_equal(kept._shrink, False)
    assert_equal(collect_list(kept^), [1, 3])
    var rejected = pipeline(linked^).elements().filter_not(mut_ref(predicate)).get()
    comptime assert type_of(rejected) == LinkedList[Int]
    assert_equal(collect_list(rejected^), [0, 2])
    var dictionary = Dict[String, Int, default_comp_time_hasher]()
    dictionary["a"] = 0
    dictionary["b"] = 1
    dictionary["c"] = 2
    dictionary["d"] = 3
    var filtered = pipeline_values(dictionary^).filter(mut_ref(predicate)).get()
    comptime assert type_of(filtered) == Dict[String, Int, default_comp_time_hasher]
    assert_equal(filtered["b"], 1)
    assert_equal(filtered["d"], 3)
    assert_equal(collect_list(filtered^), ["b", "d"])
    var keywords = StringDict[Int]()
    keywords["a"] = 0
    keywords["b"] = 1
    keywords["c"] = 2
    keywords["d"] = 3
    var selected = pipeline_values(keywords^).filter_not(mut_ref(predicate)).get()
    assert_equal(selected["a"], 0)
    assert_equal(selected["c"], 2)
    assert_equal(len(selected), 2)
    assert_equal(predicate.calls, 16)
    var nonempty = NonEmptyList(0, [1, 2, 3])
    var result = pipeline[NonEmptyListFamily](nonempty^).filter_not(mut_ref(predicate)).get()
    comptime assert type_of(result) == List[Int]
    assert_equal(result, [0, 2])
    assert_equal(predicate.calls, 20)
