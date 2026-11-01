from fp.iteration import fold_left
from std.iter import iter
from std.testing import assert_equal


def subtract(var acc: Int, var item: Int) -> Int:
    return acc - item


def main() raises:
    # Concatenation law needs no associativity; subtraction makes that visible.
    for length in range(10):
        for cut in range(length + 1):
            var all = fold_left(iter(range(length)), 100, subtract)
            var left = fold_left(iter(range(cut)), 100, subtract)
            var right = fold_left(iter(range(cut, length)), left, subtract)
            assert_equal(all, right)
