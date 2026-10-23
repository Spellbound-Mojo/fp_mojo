"""Native forwarding, lazy prefix scheduling and consuming terminal contracts."""
from fp.iteration import iterated, zip_with, map_with_index, take_while, drop_while
from std.testing import assert_equal

def pair(var a: Int, var b: Int) -> Int: return a + b
def less(x: Int) -> Bool: return x < 3
def sink(var x: Int) -> NoneType: return None

def main() raises:
    assert_equal(iterated(range(6)).take(3).drop(1).enumerate(start=4).to_list(), [(4,1),(5,2)])
    assert_equal(iterated(range(2)).zip(range(10,12), range(20,22)).to_list(), [(0,10,20),(1,11,21)])
    assert_equal(iterated(range(2)).chain(range(2,4), range(4,6)).to_list(), [0,1,2,3,4,5])
    assert_equal(iterated(range(6)).take_while[less]().to_list(), [0,1,2])
    assert_equal(iterated(range(6)).drop_while[less]().to_list(), [3,4,5])
    assert_equal(iterated(range(6)).take_while(less).to_list(), [0,1,2])
    assert_equal(iterated(range(6)).drop_while(less).to_list(), [3,4,5])
    assert_equal(iterated(range(3)).zip_with(range(10,13), pair).to_list(), [10,12,14])
    assert_equal(iterated(range(3)).map_with_index(pair, start=5).to_list(), [5,7,9])
    assert_equal(iterated(range(3)).first().value(), 0)
    assert_equal(iterated(range(3)).last().value(), 2)
    assert_equal(iterated(range(3)).is_empty(), False)
    assert_equal(iterated(range(3)).count(), 3)
    assert_equal(iterated(range(3)).contains(2), True)
    assert_equal(iterated(range(6)).count_where(less), 3)
    iterated(range(3)).for_each(sink)
    var nonempty = iterated(range(3)).to_non_empty_list()
    assert_equal(len(nonempty.value()), 3)
    traces()
    captured()
    reductions()
    bounds()

# Trace sources make advancement and restart behavior observable.
from std.iter import Iterator, IterableOwned, next, iter, empty
from std.memory import ArcPointer
from std.itertools import count as counting
from fp.algebra import StringMonoid
from fp.iteration import first, last, is_empty, count, count_where, contains, for_each, to_non_empty_list, combine_all_optional, collect_fold


@fieldwise_init
struct I12TraceSource(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var position: Int
    var end: Int
    var id: Int
    var trace: ArcPointer[List[Int]]
    def __iter__(var self) -> Self:
        self.position = 0
        return self^
    def __next__(mut self) raises StopIteration -> Int:
        self.trace[].append(self.id * 100 + self.position)
        if self.position == self.end: raise StopIteration()
        var result = self.position
        self.position += 1
        return result
    def bounds(self) -> Tuple[Int, Optional[Int]]:
        return (self.end - self.position, Optional(self.end - self.position))


@fieldwise_init
struct I12ResumingSource(Iterator):
    comptime Element = Int
    var position: Int
    def __next__(mut self) raises StopIteration -> Int:
        var result = self.position
        self.position += 1
        if result == 1: raise StopIteration()
        return result


def selected_text(var x: Int) -> Optional[String]:
    if x % 2 == 0: return Optional(String(x))
    return None


def traces() raises:
    var trace = ArcPointer(List[Int]())
    var no_pull = iterated(I12TraceSource(0,4,1,trace)).take(0).drop(-2).enumerate()
    assert_equal(len(trace[]), 0)
    assert_equal(len(no_pull^.to_list()), 0)
    assert_equal(len(trace[]), 0)
    assert_equal(iterated(range(5)).take(-1).count(), 0)
    assert_equal(iterated(range(5)).drop(-2).count(), 5)
    var a = I12TraceSource(0,4,1,trace)
    var b = I12TraceSource(0,4,2,trace)
    assert_equal(next(a),0)
    assert_equal(next(b),0)
    trace[].clear()
    var zipped = iterated(a^).zip(b^)
    assert_equal(len(trace[]),0)
    assert_equal(zipped^.to_list(), [(1,1),(2,2),(3,3)])
    assert_equal(trace[], [101,201,102,202,103,203,104])
    trace[].clear()
    assert_equal(iterated(I12TraceSource(0,3,1,trace)).zip(I12TraceSource(0,1,2,trace)).to_list(), [(0,0)])
    assert_equal(trace[], [100,200,101,201])
    trace[].clear()
    var c = I12TraceSource(1,3,1,trace)
    var d = I12TraceSource(1,3,2,trace)
    assert_equal(iterated(c^).chain(d^).to_list(), [1,2,1,2])
    assert_equal(trace[], [101,102,103,201,202,203])
    trace[].clear()
    assert_equal(iterated(I12TraceSource(0,3,1,trace)).count(), 3)
    assert_equal(trace[], [100,101,102,103])
    trace[].clear()
    assert_equal(iterated(I12TraceSource(0,3,1,trace)).contains(1), True)
    assert_equal(trace[], [100,101])
    trace[].clear()
    assert_equal(iterated(I12TraceSource(0,3,1,trace)).is_empty(), False)
    assert_equal(trace[], [100])
    trace[].clear()
    assert_equal(iterated(I12TraceSource(0,3,1,trace)).nth(1).value(), 1)
    assert_equal(trace[], [100,101])
    assert_equal(iterated(counting()).drop(2).take(3).to_list(), [2,3,4])
    assert_equal(iterated(range(1)).chain(range(1),range(1),range(1),range(1),range(1),range(1),range(1),range(1),range(1)).count(), 10)
    var wide = iterated(range(1)).zip(range(1),range(1),range(1),range(1),range(1),range(1),range(1),range(1),range(1))
    assert_equal(len(next(wide)),10)
    _ = wide^
    # Native take retains the native non-fused behavior; value-prefix is fused.
    var native = iterated(I12ResumingSource(0)).take(5)
    assert_equal(next(native), 0)
    var stopped = False
    try: _ = next(native)
    except StopIteration: stopped = True
    assert_equal(stopped,True)
    assert_equal(next(native),2)
    var fused = iterated(I12ResumingSource(0)).take_while(less)
    assert_equal(next(fused),0)
    for _ in range(2):
        stopped = False
        try: _ = next(fused)
        except StopIteration: stopped = True
        assert_equal(stopped,True)


def captured() raises:
    var calls = 0
    def prefix(x: Int) {mut calls} -> Bool:
        calls += 1
        return x < 2
    var taking = iterated(range(5)).take_while(prefix)
    assert_equal(calls,0)
    assert_equal(taking^.to_list(), [0,1])
    assert_equal(calls,3)
    calls = 0
    var dropping = iterated(range(5)).drop_while(prefix)
    assert_equal(calls,0)
    assert_equal(dropping^.to_list(), [2,3,4])
    assert_equal(calls,3)
    calls = 0
    def combine(var a: Int,var b: Int) {mut calls} -> Int:
        calls += 1
        return a + b + calls
    var indexed = iterated(range(3)).map_with_index(combine)
    assert_equal(calls,0)
    assert_equal(indexed^.to_list(), [1,4,7])
    assert_equal(calls,3)
    calls = 0
    assert_equal(iterated(range(3)).zip_with(range(3),combine).to_list(), [1,4,7])
    calls = 0
    def observe(var value: Int) {mut calls} -> NoneType:
        calls += value
        return None
    for_each(observe,range(4))
    assert_equal(calls,6)
    assert_equal(count_where(prefix,range(5)),2)


def reductions() raises:
    assert_equal(Bool(first(empty[Int]())),False)
    assert_equal(Bool(last(empty[Int]())),False)
    assert_equal(is_empty(empty[Int]()),True)
    assert_equal(count(empty[Int]()),0)
    assert_equal(contains(range(3),9),False)
    assert_equal(Bool(to_non_empty_list(empty[Int]())),False)
    var xs: List[String] = ['a','b','c']
    assert_equal(iterated(xs^).combine_all_optional[S=StringMonoid]().value(), 'abc')
    assert_equal(Bool(combine_all_optional[S=StringMonoid](empty[String]())),False)
    assert_equal(collect_fold[M=StringMonoid](selected_text,range(6)), '024')
    assert_equal(iterated(range(6)).collect_fold[M=StringMonoid](selected_text), '024')


def bounds() raises:
    var trace = ArcPointer(List[Int]())
    var native = iterated(I12TraceSource(1,6,1,trace)).drop(1).take(3).enumerate()
    assert_equal(native.bounds()[0],3)
    assert_equal(native.bounds()[1].value(),3)
    assert_equal(len(trace[]),0)
    _ = native^
    var prefix = iterated(I12TraceSource(0,6,1,trace)).drop_while(less)
    assert_equal(prefix.bounds()[0],0)
    assert_equal(prefix.bounds()[1].value(),6)
    assert_equal(next(prefix),3)
    assert_equal(prefix.bounds()[0],2)
    assert_equal(prefix.bounds()[1].value(),2)
    assert_equal(prefix^.to_list(),[4,5])
    var taken = iterated(range(6)).take_while(less)
    assert_equal(taken.bounds()[0],0)
    for _ in range(3): _ = next(taken)
    try: _ = next(taken)
    except StopIteration: pass
    assert_equal(taken.bounds()[0],0)
    assert_equal(taken.bounds()[1].value(),0)
    assert_equal(iterated(range(2)).zip().to_list(),[(0,),(1,)])
    assert_equal(iterated(range(2)).chain().to_list(),[0,1])
