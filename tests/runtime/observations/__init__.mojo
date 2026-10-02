"""Observation storage only; fixture callbacks and resource lifetimes stay local."""
from std.memory import ArcPointer
from std.testing import assert_equal

comptime Counter = ArcPointer[Int]
comptime Trace = ArcPointer[List[Int]]


def count(counter: Counter):
    counter[] += 1


def record(trace: Trace, event: Int):
    trace[].append(event)


def assert_released(live: List[Int], drops: List[Int]) raises:
    """Check every identity after its owning scope has completed, without ordering."""
    assert_equal(len(live), len(drops))
    for i in range(len(live)):
        assert_equal(live[i], 0)
        assert_equal(drops[i], 1)
