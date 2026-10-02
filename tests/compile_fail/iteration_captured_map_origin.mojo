# error: .I.origin
# error: origin_of(local)
from fp.iteration import map, scan_left
from std.iter import iter
from std.testing import assert_equal

def borrowed(values: List[Int]) -> List[Int].IteratorType[origin_of(values)]:
    return iter(values)

def main() raises:
    var anchor: List[Int] = [1, 2]
    var local: List[Int] = [1, 2]
    var offset = 2
    def callback(var value: Int) {var offset} -> Int: return value + offset
    var expected = map(callback, borrowed(anchor))
    var candidate = map(callback, borrowed(local))
    var mapped: type_of(expected) = candidate^
    assert_equal(mapped.__next__(), 3)
    assert_equal(mapped.__next__(), 4)
    var steps = 0
    def step(var total: Int, var value: Int) {var offset, mut steps} -> Int:
        steps += 1
        return total + value + offset
    var expected_scan = scan_left(step, 0, borrowed(anchor))
    var candidate_scan = scan_left(step, 0, borrowed(anchor))
    var scanned: type_of(expected_scan) = candidate_scan^
    assert_equal(scanned.__next__(), 0)
    assert_equal(steps, 0)
    assert_equal(scanned.__next__(), 3)
    assert_equal(scanned.__next__(), 7)
    assert_equal(steps, 2)
    assert_equal(anchor, [1, 2])
    _ = expected^
    _ = expected_scan^
