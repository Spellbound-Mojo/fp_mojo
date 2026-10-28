"""Receiver priority, generic forwarding, empty input, and exact predicate errors."""
from fp.callables import BorrowCallContract, BorrowCallable, BorrowMutableCallable, BorrowOnceCallable, RepeatableBorrow, BorrowCallCompatible, invoke_borrowed_repeated
from fp.iteration import iterated, find, any as any_match, all as all_match
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Source(Iterator):
    comptime Element=Int
    var length:Int
    var pulls:ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[]+=1
        if self.pulls[]>self.length: raise StopIteration()
        return self.pulls[]

@fieldwise_init
struct Dual(BorrowCallable,BorrowMutableCallable,BorrowOnceCallable,ImplicitlyCopyable):
    comptime Payload=Int
    comptime Result=Bool
    var calls:Int
    def invoke(self,ref value:Int)->Bool:return False
    def invoke_once(deinit self,ref value:Int)->Bool:return False
    def invoke_mut(mut self,ref value:Int)->Bool:
        self.calls+=1
        return self.calls==2

@fieldwise_init
struct Failure(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    comptime Failure=StopIteration
    var calls:Int
    def invoke_mut(mut self,ref value:Int) raises StopIteration -> Bool:
        self.calls+=1
        if self.calls==2:raise StopIteration()
        return False

def forwarded[E:Movable & Deinitable,F:BorrowCallContract & Movable & Deinitable,T:AnyType](ref value:T,mut callback:F
) raises E -> F.Result where BorrowCallCompatible[E,F,T] and RepeatableBorrow[F]:
    return invoke_borrowed_repeated[E](value,callback)

def search[I:Iterator,C:BorrowCallContract & Movable & Deinitable](var predicate:C,var source:I
) raises C.Failure -> Optional[I.Element] where conforms_to(I.Element,Movable & Deinitable) and C.Payload==I.Element and C.Result==Bool and RepeatableBorrow[C]:
    return iterated(source^).find(predicate^)

def main() raises:
    var callback=Dual(0)
    var value=1
    assert_equal(forwarded[Never](value,callback),False)
    assert_equal(forwarded[Never](value,callback),True)
    assert_equal(callback.calls,2)
    callback=Dual(0)
    assert_equal(Bool(find(callback,range(1,4))),False)
    assert_equal(callback.calls,0)
    var owned=find(callback^,range(1,4))
    assert_equal(owned.take(),2)
    var direct=find(Dual(0),range(1,4))
    assert_equal(direct.take(),2)
    var generic=search(Dual(0),range(1,4))
    assert_equal(generic.take(),2)
    var pulls=ArcPointer(0)
    assert_equal(Bool(find(Dual(0),Source(0,pulls))),False)
    assert_equal(pulls[],1)
    assert_equal(any_match(Dual(0),range(0)),False)
    assert_equal(all_match(Dual(0),range(0)),True)
    pulls[]=0
    var stopped=False
    try:_=search(Failure(0),Source(5,pulls))
    except error:
        comptime assert type_of(error)==StopIteration
        stopped=True
    assert_equal(stopped,True)
    assert_equal(pulls[],2)
