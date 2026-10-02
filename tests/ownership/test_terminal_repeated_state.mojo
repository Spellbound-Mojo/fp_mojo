"""Terminals borrow one move-only predicate and retain its state between calls."""
from fp.iteration import find, any, all
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct State(Movable):
    var calls: Int
    var destroyed: ArcPointer[Int]
    def __deinit__(deinit self):
        self.destroyed[] += 1


def exercise(destroyed: ArcPointer[Int]) raises:
    var state = State(0, destroyed)
    def next_number(value: Int) {var state^} -> Bool:
        state.calls += 1
        return value == state.calls

    var first = find(next_number, iter(range(1, 2)))
    assert_equal(first.take(), 1)
    assert_true(any(next_number, iter(range(2, 3))))
    assert_true(all(next_number, iter(range(3, 5))))
    var fifth = find(next_number, iter(range(5, 6)))
    assert_equal(fifth.take(), 5)
    assert_equal(destroyed[], 0)
    # A direct native call observes updates made by every preceding terminal.
    assert_true(next_number(6))


def main() raises:
    var destroyed = ArcPointer(0)
    exercise(destroyed)
    assert_equal(destroyed[], 1)
