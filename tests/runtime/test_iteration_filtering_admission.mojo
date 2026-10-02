"""The formerly rejected captured-filter call now executes lazily."""
from fp.iteration import filter, collect_list
from std.iter import iter
from std.testing import assert_equal

def main() raises:
    var offset = 3
    def predicate(value: Int) {var offset} -> Bool:
        return value > offset
    assert_equal(len(collect_list(filter(predicate, iter(range(3))))), 0)
    assert_equal(collect_list(filter(predicate, iter(range(6)))), [4, 5])
