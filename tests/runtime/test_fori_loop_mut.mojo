"""Explicit mutable counted loops retain receiver state across every schedule."""
from fp.control import fori_loop, fori_loop_mut
from fp.callables import MutableBinary, Binary, OnceBinary
from fp.functions import flow, as_binary
from std.testing import assert_equal

@fieldwise_init
struct Weighted(MutableBinary):
    var calls: Int
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_mut(mut self, var index: Int, var carry: Int) -> Int:
        self.calls += 1
        return carry + index * self.calls

@fieldwise_init
struct Both(Binary, MutableBinary, OnceBinary):
    var calls: Int
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var index: Int, var carry: Int) -> Int: return carry + index
    def call_mut(mut self, var index: Int, var carry: Int) -> Int:
        self.calls += 1
        return carry + 100
    def call_once(deinit self, var index: Int, var carry: Int) -> Int: return -999

@fieldwise_init
struct Failing(MutableBinary):
    var visited: List[Int]
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Int
    def call_mut(mut self, var index: Int, var carry: Int) raises Int -> Int:
        self.visited.append(index)
        if index == 2: raise carry
        return carry + index

def generic[F: MutableBinary](mut callback: F) raises F.Error -> Int where F.First == Int and F.Second == Int and F.Out == Int:
    return fori_loop_mut(0, 3, callback, 0)
def generic_shared[F: Binary](mut callback: F) raises F.Error -> Int where F.First == Int and F.Second == Int and F.Out == Int:
    return fori_loop_mut(0, 3, callback, 0)
def increment(var value: Int) -> Int: return value + 1
def add(var index: Int, var carry: Int) -> Int: return carry + index

def main() raises:
    var body = Weighted(0)
    assert_equal(fori_loop_mut(0, 3, body, 0), 8)
    assert_equal(body.calls, 3)
    assert_equal(fori_loop_mut[unroll=2](0, 3, body, 0), 17)
    assert_equal(body.calls, 6)
    assert_equal(fori_loop_mut[0, 3, unroll=0](body, 0), 26)
    assert_equal(body.calls, 9)
    assert_equal(generic(body), 35)
    assert_equal(body.calls, 12)
    assert_equal(fori_loop_mut(3, 3, body, 7), 7)
    assert_equal(fori_loop_mut(3, -2, body, 7), 7)
    assert_equal(fori_loop_mut[3, -2, unroll=0](body, 7), 7)
    assert_equal(body.calls, 12)
    var negative = Weighted(0)
    assert_equal(fori_loop_mut[unroll=3](-2, 3, negative, 0), 10)
    assert_equal(negative.calls, 5)
    var dual = Both(0)
    assert_equal(fori_loop(0, 3, dual, 0), 3)
    assert_equal(dual.calls, 0)
    assert_equal(fori_loop_mut(0, 3, dual, 0), 300)
    assert_equal(dual.calls, 3)
    assert_equal(generic(dual), 300)
    assert_equal(generic_shared(dual), 300)
    assert_equal(dual.calls, 9)
    var shared = as_binary(add)
    assert_equal(fori_loop_mut(0, 3, shared, 0), 3)
    assert_equal(generic_shared(shared), 3)
    var composed = flow(Weighted(0), increment)
    assert_equal(fori_loop_mut(0, 3, composed, 0), 11)
    assert_equal(composed.call_mut(1, 0), 5)
    for schedule in range(3):
        var failed = Failing(List[Int]())
        var observed = -1
        try:
            if schedule == 0: _ = fori_loop_mut(0, 5, failed, 10)
            elif schedule == 1: _ = fori_loop_mut[unroll=3](0, 5, failed, 10)
            else: _ = fori_loop_mut[0, 5, unroll=0](failed, 10)
        except error:
            comptime assert type_of(error) == Int
            observed = error
        assert_equal(observed, 11)
        assert_equal(failed.visited, [0, 1, 2])
        try: _ = fori_loop_mut[3, 5](failed, 0)
        except _: pass
        assert_equal(failed.visited, [0, 1, 2, 3, 4])
