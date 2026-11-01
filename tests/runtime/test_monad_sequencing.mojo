"""Fluent sequencing follows native branching, evaluation and ownership."""
from fp.algebra import ListFamily, IdentityFamily
from fp.callables import MutableThunk
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.iteration import iterated
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false


def ms_choices(value: Int) -> List[Int]:
    if value == 2: return List[Int]()
    return List[Int]([value+10,value+20])


def ms_make() -> List[Int]: return List[Int]([7,8])
def ms_some(value: Int) -> Optional[Int]: return Optional(value+1)
def ms_none() -> Optional[Int]: return None


@fieldwise_init
struct MSFactory(MutableThunk):
    var calls: ArcPointer[Int]
    comptime Out = List[Int]
    def call_mut(mut self) -> Self.Out:
        self.calls[] += 1
        return List[Int]([self.calls[],self.calls[]*10])


def ms_eager() raises:
    assert_equal(pipeline(List[Int]([1,2,3])).flat_pair_with(ms_choices).get(),[(1,11),(1,21),(3,13),(3,23)])
    assert_equal(pipeline[ListFamily](List[Int]([1,2,3])).flat_pair_with(ms_choices).get(),[(1,11),(1,21),(3,13),(3,23)])
    assert_equal(pipeline(Optional(4)).flat_pair_with(ms_some).get().value(),(4,5))
    var pair_calls = ArcPointer(0)
    def check(value: Int) {pair_calls} -> Result[String,String]:
        pair_calls[] += 1
        if value < 0: return Err(String('projection'))
        return Ok(String(value))
    var good = pipeline(Result[Int,String](Ok(4))).flat_pair_with(check).get()
    assert_equal(good^.raise_on_err(),(4,String('4')))
    assert_equal(pipeline(Result[Int,String](Err(String('source')))).flat_pair_with(check).get()._err().value,'source')
    assert_equal(pair_calls[],1)
    assert_equal(pipeline(Result[Int,String](Ok(-1))).flat_pair_with(check).get()._err().value,'projection')
    assert_equal(pair_calls[],2)
    def empty(value: Int) -> Optional[Int]: return None
    assert_false(pipeline(Optional(1)).flat_pair_with(empty).get())
    assert_equal(pipeline(List[Int]([1,2,3])).flat_tap(ms_choices).get(),[1,1,3,3])
    assert_equal(pipeline(List[Int]([1,2])).followed_by(ms_make).get(),[7,8,7,8])
    assert_equal(pipeline(List[Int]([1,2])).before(ms_make).get(),[1,1,2,2])
    assert_equal(pipeline[ListFamily](List[Int]([1,2,3])).flat_tap(ms_choices).get(),[1,1,3,3])
    assert_equal(pipeline(Optional(4)).flat_tap(ms_some).get().value(),4)
    assert_false(pipeline(Optional(4)).before(ms_none).get())
    var calls = ArcPointer(0)
    assert_equal(pipeline(List[Int]([1,2])).followed_by(MSFactory(calls)).get(),[1,10,2,20])
    assert_equal(calls[],2)
    assert_equal(pipeline(List[Int]([3,4])).before(MSFactory(calls)).get(),[3,3,4,4])
    assert_equal(calls[],4)
    assert_equal(pipeline(List[Int]()).before(MSFactory(calls)).get(),List[Int]())
    assert_equal(calls[],4)
    def observe(value:Int) -> Int: return value+10
    assert_equal(pipeline[IdentityFamily](5).flat_tap(observe).get(),5)
    assert_equal(pipeline[IdentityFamily](5).flat_pair_with(observe).get(),(5,15))


def ms_lazy() raises:
    var calls = ArcPointer(0)
    def choices(value: Int) {calls} -> List[Int]:
        calls[] += 1
        return ms_choices(value)
    var pending = iterated(List[Int]([1,2,3])).flat_tap(choices^)
    assert_equal(calls[],0)
    assert_equal(pending^.to_list(),[1,1,3,3])
    assert_equal(calls[],3)
    calls[] = 0
    def pair_choices(value: Int) {calls} -> List[Int]:
        calls[] += 1
        return ms_choices(value)
    var cursor = iterated(range(4))
    assert_equal(cursor.__next__(),0)
    var paired = cursor^.flat_pair_with(pair_choices^)
    assert_equal(calls[],0)
    assert_equal(paired^.to_list(),[(1,11),(1,21),(3,13),(3,23)])
    assert_equal(calls[],3)
    assert_equal(iterated(range(2)).followed_by(ms_make).to_list(),[7,8,7,8])
    assert_equal(iterated(range(2)).before(ms_make).to_list(),[0,0,1,1])
    calls[] = 0
    assert_equal(iterated(range(2)).followed_by(MSFactory(calls)).to_list(),[1,10,2,20])
    assert_equal(calls[],2)
    assert_equal(iterated(range(2)).before(MSFactory(calls)).to_list(),[0,0,1,1])
    assert_equal(calls[],4)
    # Owned mutable native captures must retain updates at O0 and O3.
    var count = List[Int]([0])
    def next_values() {var count^} -> List[Int]:
        count[0] += 1
        return List[Int]([count[0]])
    assert_equal(iterated(range(3)).followed_by(next_values^).to_list(),[1,2,3])
    # Sequencing continues from the existing cursor and skips empty sources.
    var source = iterated(range(4))
    assert_equal(source.__next__(),0)
    assert_equal(source^.before(ms_make).to_list(),[1,1,2,2,3,3])
    assert_equal(iterated(range(0)).before(MSFactory(calls)).to_list(),List[Int]())
    assert_equal(calls[],4)
    var seen = List[Int]([0])
    def inspect(value: Int) {var seen^} -> List[Int]:
        seen[0] += 1
        if seen[0] == 2: return List[Int]()
        return List[Int]([value])
    assert_equal(iterated(range(3)).flat_tap(inspect^).to_list(),[0,2])
    var count_pair = List[Int]([0])
    def project(value: Int) {var count_pair^} -> List[Int]:
        count_pair[0] += 1
        return List[Int]([count_pair[0]])
    assert_equal(iterated(range(3)).flat_pair_with(project^).to_list(),[(0,1),(1,2),(2,3)])


def main() raises:
    ms_eager()
    ms_lazy()
    print('monad sequencing: ok')
