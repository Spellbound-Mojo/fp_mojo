"""Free operations infer the source family from the value and the target family from the callback result."""
from std.collections import Deque, LinkedList
from std.testing import assert_equal, assert_true
from fp.algebra import (map, flat_map, traverse, sequence, filter, filter_not, filter_map, compact, flatten,
                        product, map2_lazy, tail_rec_m, if_effect, or_else_absent, ListFamily, OptionalFamily,
                        ResultFamily, ValidationFamily, ListMonoid, IdentityFamily)
from fp.callables import as_unary
from fp.data import Result, Ok, Err, ControlFlow, Continue, Break


def inc(var value: Int) -> Int: return value + 1
def even(value: Int) -> Bool: return value % 2 == 0
def half(var value: Int) -> Optional[Int]:
    if value % 2 == 0: return value // 2
    return None
def checked(var value: Int) -> Result[Int, List[String]]:
    if value < 0: return Err(List[String]([String(value)]))
    return Ok(value * 10)
def strict(var value: Int) raises String -> Int:
    if value < 0: raise String("negative")
    return value
def strict_even(value: Int) raises String -> Bool:
    if value < 0: raise String("negative")
    return value % 2 == 0
def repeat(var value: Int) -> List[Int]: return [value, value]
def count_down(var value: Int) -> Optional[ControlFlow[Int, Int]]:
    if value == 0: return ControlFlow[Int, Int](Break(7))
    return ControlFlow[Int, Int](Continue(value - 1))
def present() -> Optional[Int]: return 1
def absent() -> Optional[Int]: return None
def backup() -> Result[Optional[Int], String]: return Ok(Optional[Int](9))


def sources() raises:
    assert_equal(map(List[Int]([1, 2]), inc), [2, 3])
    assert_equal(map(Optional[Int](4), inc).value(), 5)
    assert_equal(map(Result[Int, String](Ok(1)), inc)._ok().value, 2)
    var deque = Deque[Int]()
    deque.append(3)
    assert_equal(map(deque^, inc)[0], 4)
    var linked = LinkedList[Int]()
    linked.append(5)
    assert_equal(len(map(linked^, inc)), 1)
    assert_equal(flat_map(List[Int]([1, 2]), repeat), [1, 1, 2, 2])
    var lists: List[List[Int]] = [[1], [2, 3]]
    assert_equal(flatten(lists^), [1, 2, 3])
    assert_equal(filter(List[Int]([1, 2, 3, 4]), even), [2, 4])
    assert_equal(filter_not(List[Int]([1, 2, 3, 4]), even), [1, 3])
    assert_equal(filter_map(List[Int]([2, 3, 4]), half), [1, 2])
    var options = List[Optional[Int]]()
    options.append(Optional[Int](1))
    options.append(Optional[Int]())
    assert_equal(compact(options^), [1])
    assert_equal(product(Optional[Int](1), Optional[Int](2)).value()[1], 2)
    assert_equal(tail_rec_m(3, count_down).value(), 7)
    assert_equal(if_effect(Optional[Bool](True), present, absent).value(), 1)
    var restored = or_else_absent(backup, Result[Optional[Int], String](Ok(Optional[Int]())))
    assert_equal(restored._ok().value.value(), 9)


def callbacks() raises:
    var offset = 10
    def shift(var value: Int) {offset} -> Int: return value + offset
    assert_equal(map(List[Int]([1]), shift), [11])
    assert_equal(map(List[Int]([1]), as_unary(inc)), [2])
    assert_equal(map(List[Int]([1]), strict), [1])
    var message = String()
    try:
        _ = map(List[Int]([-1]), strict)
    except error:
        message = error
    assert_equal(message, "negative")
    assert_equal(filter(List[Int]([2, 3]), strict_even), [2])


def targets() raises:
    assert_equal(traverse(List[Int]([2, 4]), half).value(), [1, 2])
    assert_true(not traverse(List[Int]([2, 3]), half))
    assert_equal(traverse(List[Int]([1, 2]), checked)._ok().value, [10, 20])
    assert_equal(traverse(Optional[Int](3), checked)._ok().value.value(), 30)
    var nested = List[Optional[Int]]()
    nested.append(Optional[Int](1))
    nested.append(Optional[Int](2))
    assert_equal(sequence(nested^).value(), [1, 2])
    # Fail fast by default; select accumulation explicitly.
    assert_equal(traverse(List[Int]([-1, 2, -3]), checked)._err().value, ["-1"])
    comptime Accumulating = ValidationFamily[ListMonoid[String]]
    _ = traverse[Accumulating](List[Int]([-1, 2, -3]), checked)
    # Explicit families still bind, target first.
    assert_equal(traverse[OptionalFamily, ListFamily](List[Int]([2]), half).value(), [1])
    assert_equal(traverse[S=ListFamily](List[Int]([2]), half).value(), [1])
    assert_equal(map[IdentityFamily](1, inc), 2)


def main() raises:
    sources()
    callbacks()
    targets()
