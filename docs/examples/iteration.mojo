"""Lazy selection, ordered reduction, and initial-first snapshots."""
from fp.iteration import fold_left, reduce_optional
from fp.iteration import map, filter, filter_map, flat_map, scan_left, collect_list
from std.testing import assert_equal

def add(var total: Int, var value: Int) -> Int:
    return total + value

def subtract(var total: Int, var value: Int) -> Int:
    return total - value

def main() raises:
    var values: List[Int] = [-1, 1, 3]
    var tested = 0
    var mapped = 0
    var stepped = 0
    var factor = 2

    def positive(value: Int) {mut tested} -> Bool:
        tested += 1
        return value > 0

    def twice(var value: Int) {mut mapped, factor} -> Int:
        mapped += 1
        return value * factor

    def running(var total: Int, var value: Int) {mut stepped} -> Int:
        stepped += 1
        return total + value

    var selected = map(twice, filter(positive, values^))
    var scanned = scan_left(running, 0, selected^)
    assert_equal(tested, 0)
    assert_equal(mapped, 0)
    assert_equal(stepped, 0)
    var snapshots = collect_list(scanned^)
    assert_equal(tested, 3)
    assert_equal(mapped, 2)
    assert_equal(stepped, 2)
    var expected: List[Int] = [0, 2, 8]
    assert_equal(snapshots, expected)
    var checked = 0
    var expanded = 0
    var offset = 10

    def odd(var value: Int) {mut checked} -> Optional[Int]:
        checked += 1
        if value % 2: return Optional(value)
        return None

    def pair(var value: Int) {mut expanded, offset} -> List[Int]:
        expanded += 1
        return [value, value + offset]

    var pairs = flat_map(pair, filter_map(odd, range(1, 4)))
    assert_equal(checked, 0)
    assert_equal(expanded, 0)
    var outputs = collect_list(pairs^)
    var expected_pairs: List[Int] = [1, 11, 3, 13]
    assert_equal(outputs, expected_pairs)
    assert_equal(checked, 3)
    assert_equal(expanded, 2)
    assert_equal(fold_left(subtract, 10, range(1, 4)), 4)
    var empty = reduce_optional(add, range(0))
    assert_equal(Bool(empty), False)
    for i in range(len(snapshots)):
        print(snapshots[i])
