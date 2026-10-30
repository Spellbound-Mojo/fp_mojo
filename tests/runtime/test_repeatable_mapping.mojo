"""Lazy mapping admits stateful receivers through the ordinary callback API."""
from fp.callables import Unary, MutableUnary, OnceUnary, UnaryContract, RepeatableUnary
from fp.functions import flow, tupled
from fp.iteration import map, filter_map, flat_map, iterated, MapIterator, FilterMapIterator
from std.iter import Iterator, next
from std.memory import ArcPointer
from std.testing import assert_equal
from test_fixed_callables import Tally, Join, Shift

@fieldwise_init
struct Select(MutableUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    var calls: Int
    def call_mut(mut self, var value: Int) -> Optional[Int]:
        self.calls += 1
        if self.calls % 2: return Optional(value + self.calls)
        return None

@fieldwise_init
struct Expand(MutableUnary):
    comptime Arg = Int
    comptime Out = List[Int]
    var calls: ArcPointer[Int]
    def call_mut(mut self, var value: Int) -> List[Int]:
        self.calls[] += 1
        return [value, self.calls[]]

@fieldwise_init
struct Dual(Unary, MutableUnary, OnceUnary, ImplicitlyCopyable):
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def call(self, var value: Int) -> Int: return 100 + value
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return 200 + value + self.calls
    def call_once(deinit self, var value: Int) -> Int: return 900 + value

def mapped[I: Iterator, F: UnaryContract & Movable & Deinitable](var callback: F, var source: I
) -> MapIterator[F.Arg, F.Out, I, F] where I.Element == F.Arg and F.Error == Never and RepeatableUnary[F]:
    return map[F=F](source^, callback^)

def selected[U: Movable & Deinitable, I: Iterator, F: UnaryContract & Movable & Deinitable](var callback: F, var source: I
) -> FilterMapIterator[F.Arg, U, I, F] where I.Element == F.Arg and F.Out == Optional[U] and F.Error == Never and RepeatableUnary[F]:
    return filter_map[U=U, F=F](source^, callback^)

def main() raises:
    assert_equal(iterated(map(range(3), Tally(0))).collect_list(), [1, 12, 23])
    assert_equal(iterated(range(3)).map(Tally(0)).collect_list(), [1, 12, 23])
    assert_equal(iterated(mapped(Tally(0), range(3))).collect_list(), [1, 12, 23])
    var chain = flow(Tally(0), Shift(10))
    assert_equal(iterated(range(3)).map(chain^).collect_list(), [11, 22, 33])
    var pairs: List[Tuple[Int, Int]] = [(2, 3), (2, 3)]
    assert_equal(iterated(pairs^).map(tupled(Join(0))).collect_list(), [7, 8])
    assert_equal(iterated(filter_map(range(4), Select(0))).collect_list(), [1, 5])
    assert_equal(iterated(range(4)).filter_map(Select(0)).collect_list(), [1, 5])
    assert_equal(iterated(filter_map[U=Int](range(4), Select(0))).collect_list(), [1, 5])
    assert_equal(iterated(range(4)).filter_map[Int](Select(0)).collect_list(), [1, 5])
    assert_equal(iterated(selected[Int](Select(0), range(4))).collect_list(), [1, 5])
    # Custom dual-mode callbacks keep the canonical repeated-call preference.
    assert_equal(iterated(range(2)).map(Dual(0)).collect_list(), [201, 203])
    var reusable = flow(Dual(0), Shift(0))
    assert_equal(iterated(range(2)).map(reusable).collect_list(), [100, 101])
    assert_equal(iterated(range(2)).map(reusable^).collect_list(), [201, 203])
    var calls = ArcPointer(0)
    var output = flat_map(range(2), Expand(calls))
    assert_equal(calls[], 0)
    assert_equal(next(output), 0)
    assert_equal(calls[], 1)
    assert_equal(next(output), 1)
    assert_equal(calls[], 1)
    assert_equal(next(output), 1)
    assert_equal(calls[], 2)
    assert_equal(next(output), 2)
    for _ in range(2):
        var stopped = False
        try: _ = next(output)
        except _: stopped = True
        assert_equal(stopped, True)
    assert_equal(calls[], 2)
    assert_equal(iterated(range(2)).flat_map(Expand(calls)).collect_list(), [0, 3, 1, 4])
