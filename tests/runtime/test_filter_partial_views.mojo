"""One partial predicate works across lazy prefixes and eager family filtering."""
from fp.functions import partial, piped
from fp.iteration import iterated, filter, filter_not, take_while, drop_while, collect_list
from fp.algebra import ListFamily, filter as family_filter, filter_not as family_filter_not
from std.testing import assert_equal, assert_true
from std.collections import Array, Deque, LinkedList

def below(limit: Int, value: Int) -> Bool: return value < limit
def fail(offset: Int, value: Int) raises Int -> Bool: raise offset + value

def main() raises:
    var predicate = partial(below, 3)
    assert_equal(iterated(range(5)).filter(predicate).collect_list(), [0, 1, 2])
    assert_equal(iterated(range(5)).filter_not(predicate).collect_list(), [3, 4])
    assert_equal(iterated(range(5)).take_while(predicate).collect_list(), [0, 1, 2])
    assert_equal(iterated(range(5)).drop_while(predicate).collect_list(), [3, 4])
    assert_equal(collect_list(filter(range(5), predicate)), [0, 1, 2])
    assert_equal(collect_list(filter_not(range(5), predicate)), [3, 4])
    assert_equal(collect_list(take_while(range(5), predicate)), [0, 1, 2])
    assert_equal(collect_list(drop_while(range(5), predicate)), [3, 4])
    var values: List[Int] = [0, 1, 2, 3, 4]
    assert_equal(family_filter[ListFamily](values.copy(), predicate), [0, 1, 2])
    assert_equal(family_filter_not[ListFamily](values.copy(), predicate), [3, 4])
    assert_equal(piped(values.copy()).filter(predicate).get(), [0, 1, 2])
    assert_equal(piped(values.copy()).filter_not(predicate).get(), [3, 4])
    assert_equal(piped(values.copy()).filter[ListFamily](predicate).get(), [0, 1, 2])
    assert_equal(piped(values^).filter_not[ListFamily](predicate).get(), [3, 4])
    var array: Array[Int, 5] = [0, 1, 2, 3, 4]
    assert_equal(iterated(array^).take_while(predicate).collect_list(), [0, 1, 2])
    assert_equal(piped(Optional(2)).filter(predicate).get().value(), 2)
    assert_true(not piped(Optional[Int]()).filter(predicate).get())
    var queue = Deque[Int]()
    queue.append(1)
    queue.append(4)
    var kept_queue = piped(queue^).filter(predicate).get()
    assert_equal(kept_queue.pop(), 1)
    var linked = LinkedList[Int]()
    linked.append(1)
    linked.append(4)
    assert_equal(List(piped(linked^).filter(predicate).get()), [1])
    var table = Dict[String, Int]()
    table["a"] = 1
    table["b"] = 4
    var selected = piped(table^).filter(predicate).get()
    comptime assert type_of(selected) == Dict[String, Int]
    assert_equal(len(selected), 1)
    assert_equal(selected["a"], 1)
    var calls = 0
    def counted(value: Int) {mut calls} -> Bool:
        calls += 1
        return value < 3
    # Native and shared library prefix paths retain the same stopping rule.
    assert_equal(iterated(range(5)).drop_while(counted).collect_list(), [3, 4])
    assert_equal(calls, 4)
    var failure = partial(fail, 7)
    var caught = False
    try: _ = piped(List[Int]([1])).filter[ListFamily](failure).get()
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 8)
        caught = True
    assert_true(caught)
    assert_equal(iterated(range(3)).filter(predicate^).collect_list(), [0, 1, 2])
