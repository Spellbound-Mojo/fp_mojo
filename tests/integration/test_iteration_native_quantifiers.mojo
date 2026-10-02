"""Native any/all remain canonical for iterable truth values and SIMD lanes."""
from std.builtin.bool import any as native_any, all as native_all
from std.iter import map as native_map
from fp.iteration.adapters import any as predicate_any, all as predicate_all
from std.iter import iter
from std.testing import assert_equal

def positive(var value: Int) -> Bool:
    return value > 0

def borrow_positive(value: Int) -> Bool:
    return value > 0

def main() raises:
    var empty = List[Bool]()
    var truth: List[Bool] = [True, True]
    var mixed: List[Bool] = [True, False]
    assert_equal(native_any(empty), False)
    assert_equal(native_all(empty), True)
    assert_equal(native_any(truth), True)
    assert_equal(native_all(truth), True)
    assert_equal(native_any(mixed), True)
    assert_equal(native_all(mixed), False)
    var lanes = SIMD[DType.int32, 4](1, 0, 2, 0)
    assert_equal(native_any(lanes), True)
    assert_equal(native_all(lanes), False)
    # For copyable sources and static thin callbacks, native composition suffices.
    for start in range(-2, 3):
        var values: List[Int] = [start, start + 1, start + 2]
        assert_equal(native_any(native_map[positive](values)), predicate_any(borrow_positive, iter(values)))
        assert_equal(native_all(native_map[positive](values)), predicate_all(borrow_positive, iter(values)))
