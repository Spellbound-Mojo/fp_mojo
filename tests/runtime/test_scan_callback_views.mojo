"""Reusable binary scans retain inferred tuple outputs and explicit generic evidence."""
from fp.functions import partial, flow, flip
from fp.iteration import scan_map, iterated
from std.testing import assert_equal
from fp.callables import Binary, MutableBinary
from fp.iteration import ScanMapIterator
from std.iter import Iterator

def step(scale: Int, carry: Int, item: Int) -> Tuple[Int, String]:
    var total = carry + scale * item
    return (total, String(total))
def pair(var carry: Int, var item: Int) -> Tuple[Int, String]: return step(2, carry, item)
def retain(var value: Tuple[Int, String]) -> Tuple[Int, String]: return value^
def reversed_pair(var item: Int, var carry: Int) -> Tuple[Int, String]: return pair(carry, item)

@fieldwise_init
struct Dual(Binary, MutableBinary, ImplicitlyCopyable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int, String]
    def call(self, var carry: Int, var item: Int) -> Self.Out: return (carry + item, String("shared"))
    def call_mut(mut self, var carry: Int, var item: Int) -> Self.Out: return (carry + item, String("mutable"))

def generic[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable, F: Binary, I: Iterator](var callback: F, var initial: A, var source: I) -> ScanMapIterator[A, T, Y, I, F] where I.Element == T and F.First == A and F.Second == T and F.Out == Tuple[A, Y] and F.Error == Never:
    return scan_map[A=A, T=T, Y=Y](source^, initial^, callback^)

def main() raises:
    var callback = partial(step, 2)
    assert_equal(iterated(scan_map(range(3), 0, callback)).collect_list(), ["0","2","6"])
    assert_equal(iterated(range(3)).scan_map(callback, 0).collect_list(), ["0","2","6"])
    assert_equal(iterated(scan_map[Int, Int, String](range(3), 0, callback)).collect_list(), ["0","2","6"])
    assert_equal(iterated(range(3)).scan_map[Y=String](callback, 0).collect_list(), ["0","2","6"])
    assert_equal(iterated(range(3)).scan_map(partial(step, 2), 0).collect_list(), ["0","2","6"])
    var chain = flow(pair, retain)
    assert_equal(iterated(scan_map(range(3), 0, chain)).collect_list(), ["0","2","6"])
    assert_equal(iterated(range(3)).scan_map(chain, 0).collect_list(), ["0","2","6"])
    assert_equal(iterated(range(3)).scan_map(callback^, 0).collect_list(), ["0","2","6"])
    var flipped = flip(reversed_pair)
    assert_equal(iterated(scan_map(range(3), 0, flipped)).collect_list(), ["0","2","6"])
    assert_equal(iterated(range(3)).scan_map(flipped, 0).collect_list(), ["0","2","6"])
    assert_equal(iterated(generic[Int, Int, String](partial(step, 2), 0, range(3))).collect_list(), ["0","2","6"])
    var dual = Dual()
    assert_equal(iterated(range(2)).scan_map(dual, 0).collect_list(), ["mutable","mutable"])
