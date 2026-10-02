"""The initial snapshot must precede the first source advancement."""
from fp.iteration import scan_left
from std.iter import iter
from std.testing import assert_equal

def subtract(var a: Int, var b: Int) -> Int: return a - b

def main() raises:
    var scan = scan_left(subtract, 7, iter([2, 3]))
    assert_equal(scan.__next__(), 7)
    assert_equal(scan.__next__(), 5)
    assert_equal(scan.__next__(), 2)
