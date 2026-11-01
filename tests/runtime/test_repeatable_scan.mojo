"""Stateful binary callbacks enter lazy scans without an extra adapter."""
from fp.callables import BinaryContract, MutableBinary, OnceBinary, RepeatableBinary
from fp.functions import flow, flip
from fp.iteration import iterated, scan_left, ScanIterator
from std.iter import Iterator, next
from std.memory import ArcPointer
from std.testing import assert_equal
from test_fixed_callables import Join, Shift

@fieldwise_init
struct Step(MutableBinary, OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: ArcPointer[Int]
    def call_mut(mut self, var carry: Int, var value: Int) -> Int:
        self.calls[] += 1
        return carry + value + self.calls[]
    def call_once(deinit self, var carry: Int, var value: Int) -> Int: return -1

def scanned[A: Copyable & Deinitable, I: Iterator, F: BinaryContract & Movable & Deinitable](var callback: F, var initial: A, var source: I
) -> ScanIterator[A, F.Second, I, F] where F.First == A and F.Second == I.Element and F.Out == A and F.Error == Never and RepeatableBinary[F]:
    return scan_left[A=A, F=F](source^, initial^, callback^)

def main() raises:
    assert_equal(iterated(scan_left(range(2, 4), 2, Join(0))).collect_list(), [2, 5, 17])
    assert_equal(iterated(range(2, 4)).scan_left(Join(0), 2).collect_list(), [2, 5, 17])
    assert_equal(iterated(scanned(Join(0), 2, range(2, 4))).collect_list(), [2, 5, 17])
    assert_equal(iterated(range(2, 4)).scan_left[A=Int](flip(Join(0)), 2).collect_list(), [2, 5, 17])
    var chain = flow(Join(0), Shift(10))
    assert_equal(iterated(range(2, 4)).scan_left(chain^, 2).collect_list(), [2, 15, 57])
    var calls = ArcPointer(0)
    var pending = iterated(range(1, 3)).scan_left(Step(calls), 10)
    assert_equal(calls[], 0)
    assert_equal(next(pending), 10)
    assert_equal(calls[], 0)
    assert_equal(next(pending), 12)
    assert_equal(calls[], 1)
    assert_equal(next(pending), 16)
    assert_equal(calls[], 2)
    for _ in range(2):
        var stopped = False
        try: _ = next(pending)
        except StopIteration: stopped = True
        assert_equal(stopped, True)
    assert_equal(calls[], 2)
    assert_equal(iterated(range(0)).scan_left(Step(calls), 7).collect_list(), [7])
    assert_equal(calls[], 2)
