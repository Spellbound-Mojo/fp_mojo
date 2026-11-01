"""Stateful borrowing predicates use ordinary iterator operations directly."""
from fp.callables import BorrowMutableCallable, invoke_borrowed_repeated, RepeatableBorrow
from fp.iteration import iterated, filter, filter_not, take_while, drop_while, find, any as any_match, all as all_match, count_where, partition, Unbounded, collect_list
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal

@fieldwise_init
struct EveryOther(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    var calls:Int
    var observed:ArcPointer[Int]
    def invoke_mut(mut self,ref value:Int)->Bool:
        self.calls+=1
        self.observed[]+=1
        return self.calls%2==0

@fieldwise_init
struct Prefix(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    var calls:Int
    def invoke_mut(mut self,ref value:Int)->Bool:
        self.calls+=1
        return self.calls<=3

@fieldwise_init
struct Third(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    var calls:Int
    def invoke_mut(mut self,ref value:Int)->Bool:
        self.calls+=1
        return self.calls==3 and value==12

def main() raises:
    comptime assert RepeatableBorrow[Third]
    var predicate=Third(0)
    var item=12
    assert_equal(invoke_borrowed_repeated[Never](item,predicate),False)
    assert_equal(invoke_borrowed_repeated[Never](item,predicate),False)
    assert_equal(invoke_borrowed_repeated[Never](item,predicate),True)
    assert_equal(predicate.calls,3)
    var calls=ArcPointer(0)
    var pending=filter(range(6),EveryOther(0,calls))
    assert_equal(calls[],0)
    assert_equal(collect_list(pending^),[1,3,5])
    assert_equal(calls[],6)
    assert_equal(iterated(range(6)).filter(EveryOther(0,calls)).collect_list(),[1,3,5])
    assert_equal(collect_list(filter_not(range(6),EveryOther(0,calls))),[0,2,4])
    assert_equal(iterated(range(6)).filter_not(EveryOther(0,calls)).collect_list(),[0,2,4])
    assert_equal(collect_list(take_while(range(6),Prefix(0))),[0,1,2])
    assert_equal(iterated(range(6)).take_while(Prefix(0)).collect_list(),[0,1,2])
    assert_equal(collect_list(drop_while(range(6),Prefix(0))),[3,4,5])
    assert_equal(iterated(range(6)).drop_while(Prefix(0)).collect_list(),[3,4,5])
    var found=find(range(10,20),Third(0))
    assert_equal(found.take(),12)
    found=iterated(range(10,20)).find(Third(0))
    assert_equal(found.take(),12)
    assert_equal(any_match(range(10,20),Third(0)),True)
    assert_equal(iterated(range(10,20)).any(Third(0)),True)
    assert_equal(all_match(range(6),Prefix(0)),False)
    assert_equal(iterated(range(6)).all(Prefix(0)),False)
    assert_equal(count_where(range(6),EveryOther(0,calls)),3)
    assert_equal(iterated(range(6)).count_where(EveryOther(0,calls)),3)
    calls[]=0
    var branches=partition(range(4),EveryOther(0,calls),buffer=Unbounded())
    assert_equal(calls[],0)
    assert_equal(next(branches[0]),1)
    assert_equal(next(branches[1]),0)
    assert_equal(next(branches[0]),3)
    assert_equal(next(branches[1]),2)
    assert_equal(calls[],4)
    var fluent=iterated(range(4)).partition(EveryOther(0,calls),buffer=Unbounded())
    assert_equal(next(fluent[0]),1)
    assert_equal(next(fluent[1]),0)
