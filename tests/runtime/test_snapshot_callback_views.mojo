"""Shared binary steps preserve initial snapshots and explicit generic forwarding."""
from fp.functions import partial, flow, flip
from fp.iteration import scan_left, iterated
from std.testing import assert_equal
from fp.iteration import ScanIterator
from fp.callables import Binary
from std.iter import Iterator
from test_binary_callback_views import Dual

def step(scale: Int, carry: Int, item: Int) -> Int: return carry + scale * item
def add(var carry: Int, var item: Int) -> Int: return carry + item
def twice(var value: Int) -> Int: return value * 2

def generic[A: Copyable & Deinitable, F: Binary, I: Iterator](var callback: F, var initial: A, var source: I) -> ScanIterator[A, F.Second, I, F] where F.First == A and F.Second == I.Element and F.Out == A and F.Error == Never:
    return scan_left[A=A](source^, initial^, callback^)

def main() raises:
    var callback = partial(step, 2)
    assert_equal(iterated(scan_left(range(1,4), 0, callback)).collect_list(), [0,2,6,12])
    assert_equal(iterated(range(1,4)).scan_left(callback, 0).collect_list(), [0,2,6,12])
    assert_equal(iterated(range(0)).scan_left(callback, 5).collect_list(), [5])
    assert_equal(iterated(scan_left[Int](range(1,4), 0, callback)).collect_list(), [0,2,6,12])
    assert_equal(iterated(range(1,4)).scan_left[A=Int](callback, 0).collect_list(), [0,2,6,12])
    assert_equal(iterated(range(1,4)).scan_left(partial(step, 2), 0).collect_list(), [0,2,6,12])
    var chain = flow(add, twice)
    assert_equal(iterated(range(1,4)).scan_left(chain, 0).collect_list(), [0,2,8,22])
    assert_equal(iterated(scan_left(range(1,4), 0, chain)).collect_list(), [0,2,8,22])
    var swapped = flip(add)
    assert_equal(iterated(range(1,4)).scan_left(swapped, 0).collect_list(), [0,1,3,6])
    assert_equal(iterated(range(1,4)).scan_left(callback^, 0).collect_list(), [0,2,6,12])
    assert_equal(iterated(generic(partial(step, 2), 0, range(1,4))).collect_list(), [0,2,6,12])
    var dual = Dual(0)
    assert_equal(iterated(range(2)).scan_left(dual, 0).collect_list(), [0,200,401])
