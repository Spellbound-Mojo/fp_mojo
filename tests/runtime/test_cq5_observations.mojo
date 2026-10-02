"""Observation helpers reject missing and duplicate destruction per identity."""
from observations import Counter, Trace, count, record, assert_released
from std.testing import assert_equal


def main() raises:
    var calls = Counter(0)
    count(calls)
    count(calls)
    assert_equal(calls[], 2)
    var events = Trace(List[Int]())
    record(events, 7)
    record(events, 3)
    var expected: List[Int] = [7, 3]
    assert_equal(events[], expected)
    var live: List[Int] = [0, 0]
    var drops: List[Int] = [1, 1]
    assert_released(live, drops)
    for bad in range(3):
        var invalid = drops.copy()
        invalid[bad % 2] = bad * 2
        var rejected = False
        try:
            assert_released(live, invalid)
        except:
            rejected = True
        assert_equal(rejected, True)
    live[0] = 1
    var rejected = False
    try:
        assert_released(live, drops)
    except:
        rejected = True
    assert_equal(rejected, True)
