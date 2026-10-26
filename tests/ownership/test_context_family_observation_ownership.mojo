"""Selected error observers retain owned captures until execution or disposal."""
from fp.algebra import ResultFamily, ListFamily
from fp.effects import Reader, ResultT, run
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal
from test_error_observation_ownership import EOOwner, EOOnce

comptime Base=Reader[Int]
comptime Deferred=ResultT[Base,EOOwner]

@fieldwise_init
struct FlatOnce(BorrowOnceCallable):
    var output: EOOwner
    var kind: Int
    comptime Payload=EOOwner
    comptime Result=Deferred.Pure[EOOwner]
    comptime Failure=Int
    def invoke_once(deinit self,ref error:EOOwner) raises Int capturing -> Self.Result:
        if self.kind==2:raise 703
        if self.kind==1:return Deferred.fail[EOOwner](self.output^)
        return Deferred.pure(self.output^)


def once_paths() raises:
    for branch in range(4):
        var inputs=ArcPointer(0)
        var outputs=ArcPointer(0)
        var source=Deferred.pure(EOOwner(1,inputs)) if branch==0 else Deferred.fail[EOOwner](EOOwner(1,inputs))
        var pending=pipeline[Deferred](source^).flat_tap_err(FlatOnce(EOOwner(2,outputs),branch-1)).get()
        assert_equal(inputs[],0)
        assert_equal(outputs[],0)
        var value:Int
        try:
            var observed=run[Base](pending^,0)
            if observed.is_ok():value=observed._ok().value.value
            else:value=observed._err().value.value
        except error:
            comptime assert type_of(error)==Int
            value=error
        assert_equal(value,703 if branch==3 else 2 if branch==2 else 1)
        assert_equal(inputs[],1)
        assert_equal(outputs[],1)
    for execute in range(2):
        var drops=ArcPointer(0)
        var pending=pipeline[Deferred](Deferred.fail[EOOwner](EOOwner(3,drops))).tap_err(EOOnce(EOOwner(4,drops),True,False)).get()
        assert_equal(drops[],0)
        if execute:
            var result=run[Base](pending^,0)
            assert_equal(drops[],1)
            assert_equal(result._err().value.value,3)
        else:_ = pending^
        assert_equal(drops[],2)


def branches(drops:ArcPointer[Int]) raises:
    comptime I=ResultT[ListFamily,String]
    comptime R=Result[EOOwner,String]
    def observe(error:String) {drops} -> List[R]:
        return [R(Ok(EOOwner(10,drops))),R(Err(String("observer"))),R(Ok(EOOwner(11,drops)))]
    var source:List[R]=[R(Ok(EOOwner(8,drops))),R(Err(String("original")))]
    var result=pipeline[I](source^).flat_tap_err(observe).get()
    assert_equal(len(result),4)
    assert_equal(result[0]._ok().value.value,8)
    assert_equal(drops[],2)
    assert_equal(result[1]._err().value,"original")
    assert_equal(result[2]._err().value,"observer")
    assert_equal(result[3]._err().value,"original")


def main() raises:
    once_paths()
    var drops=ArcPointer(0)
    branches(drops)
    assert_equal(drops[],3)
