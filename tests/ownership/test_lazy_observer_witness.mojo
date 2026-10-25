"""Stored native observers retain origins, exact destruction and no-value calls."""
from fp.iteration import iterated
from fp.functions import piped
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ObserverGuard(Movable):
    var calls: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def paired(anchor: List[Int], calls: ArcPointer[Int], drops: ArcPointer[Int]) raises:
    var guard = ObserverGuard(calls, drops)
    @always_inline
    def project(value: Int) {anchor, var guard^} -> Span[Int, origin_of(anchor)]:
        guard.calls[] += value + 1
        return Span(anchor)
    var lazy = iterated(range(2)).pair_with(project^)
    assert_equal(calls[], 0)
    var first = next(lazy)
    assert_equal(first[0], 0)
    assert_equal(Pointer(to=first[1][0]) == Pointer(to=anchor[0]), True)
    assert_equal(drops[], 0)
    var second = next(lazy)
    assert_equal(second[1][1], 12)
    assert_equal(calls[], 3)
    _ = lazy^

def untouched(anchor: List[Int], calls: ArcPointer[Int], drops: ArcPointer[Int]):
    var guard = ObserverGuard(calls, drops)
    @always_inline
    def project(value: Int) {anchor, var guard^} -> Span[Int, origin_of(anchor)]:
        guard.calls[] += value + 1
        return Span(anchor)
    var lazy = iterated(range(2)).pair_with(project^)
    _ = lazy^

def no_value(calls: ArcPointer[Int], drops: ArcPointer[Int]) raises:
    var guard = ObserverGuard(calls, drops)
    @always_inline
    def observe(value: Int) {var guard^}:
        guard.calls[] += value + 1
    var lazy = iterated(range(2)).tap_each(observe^)
    assert_equal(next(lazy), 0)
    assert_equal(drops[], 2)
    assert_equal(next(lazy), 1)
    _ = lazy^

def main() raises:
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    var anchor: List[Int] = [11, 12]
    paired(anchor, calls, drops)
    assert_equal(drops[], 1)
    untouched(anchor, calls, drops)
    assert_equal(calls[], 3)
    assert_equal(drops[], 2)
    no_value(calls, drops)
    assert_equal(calls[], 6)
    assert_equal(drops[], 3)
    var seen = 0
    def observe(value: Int) {mut seen}:
        seen += value
    var eager = piped(List[Int]([3, 4])).tap_each(observe).get()
    assert_equal(seen, 7)
    assert_equal(eager, [3, 4])
