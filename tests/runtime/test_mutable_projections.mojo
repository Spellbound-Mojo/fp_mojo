"""Owned mutable key selectors and lazy observers infer their ordinary calls."""
from fp.callables import BorrowMutableCallable
from fp.iteration import min_by,max_by,iterated,pair_with,tap_each,collect_list,minimum_by_non_empty,maximum_by_non_empty
from fp.functions import piped,pipeline
from fp.data import NonEmptyList
from std.memory import ArcPointer
from std.testing import assert_equal
@fieldwise_init
struct Rank(BorrowMutableCallable):
    comptime Payload=String
    comptime Result=Int
    var calls:Int
    var seen:ArcPointer[Int]
    def invoke_mut(mut self,ref value:String)->Int:
        self.calls+=1
        self.seen[]+=1
        return value.byte_length()+self.calls

def values()->List[String]:return [String('aa'),String('bbb'),String('c')]
def main() raises:
    var calls=ArcPointer(0)
    assert_equal(min_by(Rank(0,calls),values()).value(),'aa')
    assert_equal(max_by(Rank(0,calls),values()).value(),'bbb')
    assert_equal(iterated(values()).min_by(Rank(0,calls)).value(),'aa')
    assert_equal(iterated(values()).max_by(Rank(0,calls)).value(),'bbb')
    assert_equal(piped(values()).min_by(Rank(0,calls)).get().value(),'aa')
    assert_equal(piped(values()).max_by(Rank(0,calls)).get().value(),'bbb')
    assert_equal(pipeline(values()).min_by(Rank(0,calls)).get().value(),'aa')
    assert_equal(pipeline(values()).max_by(Rank(0,calls)).get().value(),'bbb')
    assert_equal(minimum_by_non_empty(Rank(0,calls),NonEmptyList(String('aa'),[String('bbb'),String('c')])),'aa')
    assert_equal(maximum_by_non_empty(Rank(0,calls),NonEmptyList(String('aa'),[String('bbb'),String('c')])),'bbb')
    assert_equal(calls[],30)
    calls[]=0
    var lazy=iterated(values()).pair_with(Rank(0,calls))
    assert_equal(calls[],0)
    var paired=lazy^.to_list()
    assert_equal(paired,[(String('aa'),3),(String('bbb'),5),(String('c'),4)])
    assert_equal(calls[],3)
    assert_equal(collect_list(pair_with(Rank(0,calls),values())),paired)
    assert_equal(collect_list(tap_each(Rank(0,calls),values())),values())
    assert_equal(iterated(values()).tap_each(Rank(0,calls)).to_list(),values())
    assert_equal(calls[],12)
