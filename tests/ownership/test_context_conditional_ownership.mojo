"""Conditional factories retain captures and release selected, skipped and abandoned owners."""
from fp.functions import pipeline
from fp.callables import OnceThunk,MutableThunk
from fp.effects import Reader,run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct BranchOwner(Movable):
    var id:Int
    var drops:ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
@fieldwise_init
struct OnceFactory(OnceThunk):
    var value:BranchOwner
    comptime Out=Optional[BranchOwner]
    def call_once(deinit self)->Self.Out: return Optional(self.value^)
@fieldwise_init
struct CountingFactory(MutableThunk):
    var count:Int
    comptime Out=List[Int]
    def call_mut(mut self)->Self.Out:
        self.count += 1
        return List[Int]([self.count])

def main() raises:
    var drops=ArcPointer(0)
    var selected=pipeline(Optional(True)).if_effect(OnceFactory(BranchOwner(1,drops)),OnceFactory(BranchOwner(2,drops))).get()
    assert_equal(selected.value().id,1); assert_equal(drops[],1)
    _ = selected^
    assert_equal(drops[],2)
    drops[]=0
    _ = pipeline(Optional[Bool]()).if_effect(OnceFactory(BranchOwner(1,drops)),OnceFactory(BranchOwner(2,drops))).get()
    assert_equal(drops[],2)
    var repeated=pipeline(List[Bool]([True,False,True])).if_effect(CountingFactory(0),CountingFactory(10)).get()
    assert_equal(repeated,List[Int]([1,11,2]))
    comptime Deferred=Reader[Int]
    var calls=ArcPointer(0)
    def left() {calls} -> Deferred.Pure[Int]:
        calls[] += 1
        return Deferred.pure(1)
    def right() {calls} -> Deferred.Pure[Int]:
        calls[] += 10
        return Deferred.pure(2)
    var pending=pipeline[Deferred](Deferred.pure(False)).if_effect(left,right).get()
    assert_equal(calls[],0)
    assert_equal(run[Deferred](pending^,0),2); assert_equal(calls[],10)
    calls[]=0
    var abandoned=pipeline[Deferred](Deferred.pure(True)).if_effect(left,right).get()
    _ = abandoned^
    assert_equal(calls[],0)
