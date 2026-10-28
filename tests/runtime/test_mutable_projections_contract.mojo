"""Repeated receiver selection, generic forwarding, ties, and exact callback errors."""
from fp.callables import BorrowCallContract,BorrowCallable,BorrowMutableCallable,BorrowOnceCallable,RepeatableBorrow
from fp.iteration import min_by,max_by,iterated,minimum_by_non_empty
from fp.functions import piped,pipeline
from fp.data import NonEmptyList
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal
@fieldwise_init
struct Dual(BorrowCallable,BorrowMutableCallable,BorrowOnceCallable,ImplicitlyCopyable):
    comptime Payload=Int
    comptime Result=Int
    var calls:Int
    def invoke(self,ref value:Int)->Int:return value
    def invoke_once(deinit self,ref value:Int)->Int:return value
    def invoke_mut(mut self,ref value:Int)->Int:
        self.calls+=1
        return -value
@fieldwise_init
struct Stop(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    comptime Failure=StopIteration
    var seen:ArcPointer[Int]
    def invoke_mut(mut self,ref value:Int) raises StopIteration -> Int:
        self.seen[]+=1
        if self.seen[]==2:raise StopIteration()
        return value
@fieldwise_init
struct Count(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    var seen:ArcPointer[Int]
    def invoke_mut(mut self,ref value:Int)->Int:
        self.seen[]+=1
        return 0

def forwarded[I:Iterator,C:BorrowCallContract & Movable & Deinitable](var key:C,var source:I
) raises C.Failure -> Optional[C.Payload] where conforms_to(C.Payload,Movable & Deinitable) and I.Element==C.Payload and conforms_to(C.Result,Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
    return min_by(key^,source^)

def main() raises:
    assert_equal(min_by(Dual(0),range(1,4)).value(),3)
    assert_equal(max_by(Dual(0),range(1,4)).value(),1)
    assert_equal(iterated(range(1,4)).min_by(Dual(0)).value(),3)
    assert_equal(piped(List[Int]([1,2,3])).min_by(Dual(0)).get().value(),3)
    assert_equal(pipeline(range(1,4)).min_by(Dual(0)).get().value(),3)
    assert_equal(minimum_by_non_empty(Dual(0),NonEmptyList(1,[2,3])),3)
    assert_equal(forwarded(Dual(0),range(1,4)).value(),3)
    assert_equal(iterated(range(1,4)).pair_with(Dual(0)).to_list(),[(1,-1),(2,-2),(3,-3)])
    var seen=ArcPointer(0)
    assert_equal(Bool(min_by(Count(seen),range(0))),False)
    assert_equal(seen[],0)
    assert_equal(min_by(Count(seen),range(3,7)).value(),3)
    assert_equal(seen[],4)
    seen[]=0
    assert_equal(max_by(Count(seen),range(3,7)).value(),3)
    assert_equal(seen[],4)
    seen[]=0
    assert_equal(minimum_by_non_empty(Count(seen),NonEmptyList(9)),9)
    assert_equal(seen[],1)
    seen[]=0
    var caught=False
    try:_=forwarded(Stop(seen),range(10))
    except error:
        comptime assert type_of(error)==StopIteration
        caught=True
    assert_equal(caught,True)
    assert_equal(seen[],2)
