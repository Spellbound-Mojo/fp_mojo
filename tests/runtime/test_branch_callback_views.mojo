"""Named predicates and classifiers keep free and fluent branch behavior."""
from fp.functions import partial, as_unary, flow
from fp.iteration import iterated, partition, partition_map, Unbounded, BoundedFail
from fp.data import Result, Ok, Err
from std.iter import next
from std.os import abort
from std.testing import assert_equal, assert_true

def below(limit: Int, value: Int) -> Bool: return value < limit
def classify(limit: Int, value: Int) -> Result[Int, String]:
    if value < limit: return Ok(value)
    return Err(String(value))
def increment(var value: Int) -> Int: return value + 1
def route(var value: Int) -> Result[Int, String]: return classify(2, value)
def capacity() -> BoundedFail:
    try: return BoundedFail(1)
    except: abort("one is a valid capacity")

def main() raises:
    var predicate = partial(below, 2)
    var branches = partition(range(4), predicate, buffer=Unbounded())
    assert_equal(next(branches[0]), 0)
    assert_equal(next(branches[1]), 2)
    assert_equal(next(branches[0]), 1)
    assert_equal(next(branches[1]), 3)
    var again = iterated(range(4)).partition(predicate, buffer=Unbounded())
    assert_equal(next(again[0]), 0)
    assert_equal(next(again[1]), 2)
    var project = partial(classify, 2)
    var classified = partition_map(range(4), project, buffer=Unbounded())
    assert_equal(next(classified[0]), 0)
    assert_equal(next(classified[1]), "2")
    var classified_again = iterated(range(4)).partition_map(project, buffer=Unbounded())
    assert_equal(next(classified_again[0]), 0)
    assert_equal(next(classified_again[1]), "2")
    var bounded = partition(range(5), predicate, buffer=capacity())
    assert_equal(next(bounded[0])._take_ok(), 0)
    assert_equal(next(bounded[0])._take_ok(), 1)
    assert_equal(next(bounded[0])._take_err().branch, 1)
    assert_equal(next(bounded[1])._take_err().capacity, 1)
    var bounded_map = iterated(range(5)).partition_map(project, buffer=capacity())
    assert_equal(next(bounded_map[0])._take_ok(), 0)
    assert_equal(next(bounded_map[0])._take_ok(), 1)
    assert_equal(next(bounded_map[0])._take_err().branch, 1)
    assert_true(next(bounded_map[1]).is_err())
    var closed = partition(range(5), predicate, buffer=capacity())
    closed[1].close()
    assert_equal(next(closed[0])._take_ok(), 0)
    assert_equal(next(closed[0])._take_ok(), 1)
    var stopped = False
    try: _ = next(closed[0])
    except StopIteration: stopped = True
    assert_true(stopped)
    var offset = 10
    def captured(var value: Int) {offset} -> Result[Int, String]:
        if value < 2: return Ok(value + offset)
        return Err(String(value))
    var native = as_unary(captured)
    var owned = partition_map(range(4), native, buffer=Unbounded())
    assert_equal(next(owned[0]), 10)
    assert_equal(next(owned[1]), "2")
    var owned_again = iterated(range(4)).partition_map(native, buffer=Unbounded())
    assert_equal(next(owned_again[0]), 10)
    var chain = flow(increment, route)
    var composed = partition_map(range(4), chain, buffer=Unbounded())
    assert_equal(next(composed[0]), 1)
    assert_equal(next(composed[1]), "2")
    var composed_again = iterated(range(4)).partition_map(chain, buffer=Unbounded())
    assert_equal(next(composed_again[0]), 1)
    _ = classified^
    _ = classified_again^
    _ = bounded_map^
    var moved = partition_map(range(3), project^, buffer=Unbounded())
    assert_equal(next(moved[1]), "2")
    var temporary = iterated(range(3)).partition(partial(below, 2), buffer=Unbounded())
    assert_equal(next(temporary[1]), 2)
