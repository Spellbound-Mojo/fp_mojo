"""Counted loops consume mutable callback values through canonical scheduling."""
from fp.control import fori_loop
from fp.callables import Binary, MutableBinary, OnceBinary, BinaryContract, RepeatableBinary, mut_ref
from std.testing import assert_equal
from test_fori_loop_mut import Failing

@fieldwise_init
struct Step(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var index: Int, var carry: Int) -> Int:
        self.calls += 1
        return carry + index * self.calls

@fieldwise_init
struct Modes(Binary, MutableBinary, OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call(self, var index: Int, var carry: Int) -> Int: return carry + index
    def call_mut(mut self, var index: Int, var carry: Int) -> Int:
        self.calls += 1
        return carry + index * self.calls
    def call_once(deinit self, var index: Int, var carry: Int) -> Int: return 999

def forward[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var body: F, var initial: A) raises F.Error -> A where RepeatableBinary[F] and F.First == Int and F.Second == A and F.Out == A:
    return fori_loop[unroll=2](0,4,body^,initial^)

def main() raises:
    assert_equal(fori_loop(0,4,Step(0),0),20)
    assert_equal(fori_loop[0,4,unroll=0](Step(0),0),20)
    assert_equal(forward(Step(0),0),20)
    var state = Step(0)
    assert_equal(fori_loop(0,4,mut_ref(state),0),20)
    assert_equal(state.calls,4)
    var named = Modes(0)
    assert_equal(fori_loop(0,4,named,0),6)
    assert_equal(fori_loop[0,4,unroll=0](named,0),6)
    assert_equal(named.calls,0)
    assert_equal(fori_loop(0,4,named^,0),20)
    assert_equal(fori_loop[0,4,unroll=2](Modes(0),0),20)

    var empty = Step(0)
    assert_equal(fori_loop(3,3,mut_ref(empty),7),7)
    assert_equal(fori_loop[3,-2,unroll=0](mut_ref(empty),7),7)
    assert_equal(empty.calls,0)
    assert_equal(fori_loop[unroll=3](-2,3,Step(0),0),10)
    var failed = Failing(List[Int]())
    var observed = -1
    try:
        _ = fori_loop[unroll=3](0,5,mut_ref(failed),0)
    except error:
        comptime assert type_of(error) == Int
        observed = error
    assert_equal(observed,1)
    var expected: List[Int] = [0,1,2]
    assert_equal(failed.visited,expected)
