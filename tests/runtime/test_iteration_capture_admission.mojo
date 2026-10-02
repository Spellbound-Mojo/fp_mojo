"""The former captured-map rejection now executes through native Iterator."""
from fp.iteration import map
from std.iter import iter

def main() raises:
    var offset = 3
    def callback(var value: Int) {var offset} -> Int:
        return value + offset
    from fp.iteration import collect_list
    from std.testing import assert_equal
    var values = collect_list(map(callback, iter(range(3))))
    assert_equal(values, [3, 4, 5])
