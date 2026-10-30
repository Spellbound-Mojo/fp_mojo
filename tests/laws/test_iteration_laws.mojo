"""Bounded ordered-list reference laws; no associativity assumption for folds."""
from fp.iteration import map, filter, filter_map, flat_map, flatten, scan_left, collect_list, find, any, all
from fp.iteration import fold_left
from std.iter import iter
from std.testing import assert_equal

def twice(var value: Int) -> Int: return 2 * value
def negate(var value: Int) -> Int: return -value
def composed(var value: Int) -> Int: return -2 * value
def even(value: Int) -> Bool: return value % 2 == 0
def selected(var value: Int) -> Optional[Int]:
    return Optional(twice(value)) if even(value) else None
def nested(var value: Int) -> List[Int]:
    return [value, -value] if even(value) else List[Int]()
def subtract(var acc: Int, var value: Int) -> Int: return acc - value

def main() raises:
    for length in range(8):
        var expected = List[Int]()
        var expected_flat = List[Int]()
        var expected_scan: List[Int] = [17]
        var total = 17
        for value in range(length):
            if even(value):
                expected.append(2 * value)
                expected_flat.append(value)
                expected_flat.append(-value)
            total -= value
            expected_scan.append(total)
        assert_equal(collect_list(map(iter(range(length)), composed)),
                     collect_list(map(map(iter(range(length)), twice), negate)))
        assert_equal(collect_list(filter_map(iter(range(length)), selected)), expected)
        assert_equal(collect_list(map(filter(iter(range(length)), even), twice)), expected)
        assert_equal(collect_list(flat_map(iter(range(length)), nested)), expected_flat)
        assert_equal(collect_list(flatten(map(iter(range(length)), nested))), expected_flat)
        var states = collect_list(scan_left(iter(range(length)), 17, subtract))
        assert_equal(states, expected_scan)
        assert_equal(states[len(states) - 1], fold_left(iter(range(length)), 17, subtract))
        assert_equal(any(iter(range(length)), even), length > 0)
        assert_equal(all(iter(range(length)), even), length < 2)
        var found = find(iter(range(length)), even)
        assert_equal(Bool(found), length > 0)
        if found: assert_equal(found.take(), 0)
