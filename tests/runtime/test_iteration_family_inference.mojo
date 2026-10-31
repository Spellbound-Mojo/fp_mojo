"""Free iteration traversals infer their target family from the callback result."""
from std.testing import assert_equal, assert_true
from fp.iteration import (traverse, flat_traverse, traverse_filter, traverse_tap, traverse_void, filter_effect,
                          any_effect, all_effect, find_effect, find_map_effect, fold_effect, fold_map_effect, sequence)
from fp.algebra import OptionalFamily, StringMonoid
from fp.data import Result, Ok, Err


def half(var value: Int) -> Optional[Int]:
    if value % 2 == 0: return value // 2
    return None
def checked(var value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative"))
    return Ok(value)
def pair(var value: Int) -> Optional[List[Int]]: return List[Int]([value, value])
def keep_even(var value: Int) -> Optional[Optional[Int]]:
    if value % 2 == 0: return Optional[Optional[Int]](Optional[Int](value))
    return Optional[Optional[Int]](Optional[Int]())
def observe(value: Int) -> Optional[Int]: return value
def is_even(value: Int) -> Optional[Bool]: return value % 2 == 0
def add(var total: Int, var value: Int) -> Optional[Int]: return total + value
def text(var value: Int) -> Optional[String]: return String(value)
def strict(var value: Int) raises String -> Optional[Int]:
    if value < 0: raise String("negative")
    return value


def main() raises:
    assert_equal(traverse(List[Int]([2, 4]), half).value(), [1, 2])
    assert_true(not traverse(List[Int]([2, 3]), half))
    assert_equal(traverse(List[Int]([1, -1]), checked)._err().value, "negative")
    assert_equal(flat_traverse(List[Int]([1, 2]), pair).value(), [1, 1, 2, 2])
    assert_equal(traverse_filter(List[Int]([1, 2, 4]), keep_even).value(), [2, 4])
    assert_equal(traverse_tap(List[Int]([1, 2]), observe).value(), [1, 2])
    assert_true(Bool(traverse_void(List[Int]([2]), half)))
    assert_equal(filter_effect(List[Int]([1, 2, 3, 4]), is_even).value(), [2, 4])
    assert_true(any_effect(List[Int]([1, 2]), is_even).value())
    assert_true(not all_effect(List[Int]([1, 2]), is_even).value())
    assert_equal(find_effect(List[Int]([1, 2, 3]), is_even).value().value(), 2)
    assert_equal(find_map_effect(List[Int]([1, 2]), keep_even).value().value(), 2)
    assert_equal(fold_effect(List[Int]([1, 2, 3]), 0, add).value(), 6)
    assert_equal(fold_map_effect[StringMonoid](List[Int]([1, 2]), text).value(), "12")
    assert_equal(traverse(List[Int]([1]), strict).value(), [1])
    var nested = List[Optional[Int]]()
    nested.append(Optional[Int](1))
    assert_equal(sequence(nested^).value(), [1])
    # An explicit target still binds.
    assert_equal(traverse[OptionalFamily](List[Int]([2]), half).value(), [1])
