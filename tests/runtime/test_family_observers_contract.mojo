"""Observation selects receivers by cardinality and preserves generic effects."""
from fp.callables import BorrowCallContract,BorrowCallable,BorrowMutableCallable,BorrowOnceCallable,RepeatableBorrow
from fp.callables._transforms import _Observe
from fp.functions import piped,pipeline
from fp.algebra import Functor,ListFamily,OptionalFamily
from fp.data import Result,Ok,Err
from std.collections import Array
from std.memory import ArcPointer
from std.testing import assert_equal
@fieldwise_init
struct Modes(BorrowCallable,BorrowMutableCallable,BorrowOnceCallable,ImplicitlyCopyable):
    comptime Payload=Int
    comptime Result=Int
    var calls:Int
    var modes:ArcPointer[List[Int]]
    def invoke(self,ref value:Int)->Int:
        self.modes[].append(1)
        return -1
    def invoke_mut(mut self,ref value:Int)->Int:
        self.calls+=1
        self.modes[].append(2)
        return value+self.calls
    def invoke_once(deinit self,ref value:Int)->Int:
        self.modes[].append(3)
        return -3
@fieldwise_init
struct Fail(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    comptime Failure=Int
    var calls:ArcPointer[Int]
    def invoke_mut(mut self,ref value:Int) raises Int -> Int:
        self.calls[]+=1
        if self.calls[]==2:raise 37
        return value

def forward[I:Functor,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var project:C
) raises I.MapError[V,_Observe[I.Element[V],C,True]] -> I.Mapped[V,_Observe[I.Element[V],C,True]] where C.Payload==I.Element[V] and RepeatableBorrow[C] and I.MapCompatible[V,_Observe[I.Element[V],C,True]]:
    return pipeline[I](source^).pair_with(project^).get()

def main() raises:
    var modes=ArcPointer(List[Int]())
    var callback=Modes(0,modes)
    assert_equal(pipeline[Int]([1,2]).pair_with(callback^).get(),[(1,2),(2,4)])
    assert_equal(piped(List[Int]([1,2])).pair_with(Modes(0,modes)).get(),[(1,2),(2,4)])
    assert_equal(pipeline(5).tap(Modes(0,modes)).get(),5)
    assert_equal(piped(5).tap(Modes(0,modes)).get(),5)
    assert_equal(modes[],[2,2,2,2,3,3])
    assert_equal(forward[ListFamily](List[Int]([1,2]),Modes(0,modes)),[(1,2),(2,4)])
    assert_equal(forward[OptionalFamily](Optional(5),Modes(0,modes)).value(),(5,6))
    var array:Array[Int,2]=[1,2]
    assert_equal(piped(array^).pair_with(Modes(0,modes)).get()[1],(2,4))
    assert_equal(pipeline(Result[Int,String](Ok(8))).pair_with(Modes(0,modes)).get()._take_ok(),(8,9))
    var size=len(modes[])
    assert_equal(pipeline(Result[Int,String](Err(String('stored')))).pair_with(Modes(0,modes)).get().is_err(),True)
    assert_equal(Bool(pipeline(Optional[Int]()).pair_with(Modes(0,modes)).get()),False)
    assert_equal(pipeline(List[Int]()).pair_with(Modes(0,modes)).get(),List[Tuple[Int,Int]]())
    assert_equal(len(modes[]),size)
    var calls=ArcPointer(0)
    var code=0
    try:_=forward[ListFamily](List[Int]([1,2,3]),Fail(calls))
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,37)
    assert_equal(calls[],2)
