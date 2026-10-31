"""Pipeline methods infer the held value's family and a traversal's target, without per-carrier copies."""
from std.collections import Deque, LinkedList
from std.testing import assert_equal, assert_true
from fp.functions import pipeline
from fp.algebra import ListFamily, OptionalFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err


def inc(var value: Int) -> Int: return value + 1
def even(value: Int) -> Bool: return value % 2 == 0
def half(var value: Int) -> Optional[Int]:
    if value % 2 == 0: return value // 2
    return None
def checked(var value: Int) -> Result[Int, List[String]]:
    if value < 0: return Err(List[String]([String(value)]))
    return Ok(value)
def repeat(var value: Int) -> List[Int]: return [value, value]
def strict(var value: Int) raises String -> Int:
    if value < 0: raise String("negative")
    return value
def strict_even(value: Int) raises String -> Bool:
    if value < 0: raise String("negative")
    return value % 2 == 0
def strict_half(var value: Int) raises String -> Optional[Int]:
    if value < 0: raise String("negative")
    return value
def observe(value: Int) -> Optional[Int]: return value
def is_even(value: Int) -> Optional[Bool]: return value % 2 == 0


def carriers() raises:
    assert_equal(pipeline(List[Int]([1, 2])).map(inc).get(), [2, 3])
    assert_equal(pipeline(Optional[Int](1)).map(inc).get().value(), 2)
    assert_equal(pipeline(Result[Int, String](Ok(1))).map(inc).get()._ok().value, 2)
    var deque = Deque[Int]()
    deque.append(2)
    deque.append(3)
    var kept = pipeline(deque^).filter(even).get()
    comptime assert type_of(kept) == Deque[Int]
    assert_equal(len(kept), 1)
    var linked = LinkedList[Int]()
    linked.append(4)
    assert_equal(len(pipeline(linked^).filter_map(half).get()), 1)
    assert_equal(pipeline(List[Int]([1, 2])).flat_map(repeat).get(), [1, 1, 2, 2])
    assert_equal(pipeline(List[Int]([1, 2, 3])).filter_not(even).get(), [1, 3])
    assert_equal(pipeline(List[Int]([1])).fill(String("x")).get(), [String("x")])
    assert_equal(len(pipeline(List[Int]([1])).tap_each(observe).get()), 1)
    assert_true(Bool(pipeline(Optional[Int](1)).product(Optional[Int](2)).get()))


def callbacks() raises:
    var offset = 10
    def shift(var value: Int) {offset} -> Int: return value + offset
    assert_equal(pipeline(List[Int]([1])).map(shift).get(), [11])
    # Raising plain functions select their native String error.
    var mapped = List[Int]()
    var kept = List[Int]()
    var halves = List[Int]()
    try:
        mapped = pipeline(List[Int]([1])).map(strict).get()
        kept = pipeline(List[Int]([2, 3])).filter(strict_even).get()
        halves = pipeline(List[Int]([2])).filter_map(strict_half).get()
    except error:
        raise Error(error)
    assert_equal(mapped, [1])
    assert_equal(kept, [2])
    assert_equal(halves, [2])
    var message = String()
    try:
        _ = pipeline(List[Int]([-1])).map(strict).get()
    except error:
        message = error
    assert_equal(message, "negative")


def targets() raises:
    assert_equal(pipeline(List[Int]([2, 4])).traverse(half).get().value(), [1, 2])
    assert_true(pipeline(List[Int]([-1])).traverse(checked).get().is_err())
    comptime Accumulating = ValidationFamily[ListMonoid[String]]
    _ = pipeline(List[Int]([-1, -2])).traverse[Accumulating](checked).get()
    assert_equal(pipeline[ListFamily](List[Int]([2])).traverse[OptionalFamily](half).get().value(), [1])
    assert_equal(pipeline(List[Int]([1, 2])).traverse_tap(observe).get().value(), [1, 2])
    assert_equal(pipeline(List[Int]([1, 2])).filter_effect(is_even).get().value(), [2])
    var nested = List[Optional[Int]]()
    nested.append(Optional[Int](1))
    assert_equal(pipeline(nested^).sequence().get().value(), [1])
    assert_equal(pipeline(Optional[Bool](True)).if_effect(present_one, absent_one).get().value(), 1)


def present_one() -> Optional[Int]: return 1
def absent_one() -> Optional[Int]: return None


def main() raises:
    carriers()
    callbacks()
    targets()
