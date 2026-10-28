"""Mutable family observers retain state; whole-value tap also consumes callbacks."""
from fp.callables import BorrowMutableCallable,BorrowOnceCallable
from fp.functions import pipeline,piped
from fp.effects import ReaderT,run
from fp.algebra import ListFamily,OptionalFamily
from fp.data import Result,Ok,Err
from std.memory import ArcPointer
from std.testing import assert_equal
@fieldwise_init
struct Key(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    var calls:Int
    var seen:ArcPointer[List[Int]]
    def invoke_mut(mut self,ref value:Int)->Int:
        self.calls+=1
        self.seen[].append(value+self.calls)
        return value+self.calls

@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Int
    var seen:ArcPointer[List[Int]]
    def invoke_once(deinit self,ref value:Int)->Int:
        self.seen[].append(value)
        return value

def main() raises:
    var seen=ArcPointer(List[Int]())
    assert_equal(pipeline(List[Int]([1,2,3])).pair_with(Key(0,seen)).get(),[(1,2),(2,4),(3,6)])
    assert_equal(seen[],[2,4,6])
    seen[].clear()
    assert_equal(piped(List[Int]([1,2,3])).pair_with(Key(0,seen)).get(),[(1,2),(2,4),(3,6)])
    assert_equal(piped(Optional(5)).pair_with(Key(0,seen)).get().value(),(5,6))
    assert_equal(pipeline(Optional(5)).pair_with(Key(0,seen)).get().value(),(5,6))
    assert_equal(pipeline(List[Int]([1,2,3])).tap_each(Key(0,seen)).get(),[1,2,3])
    assert_equal(piped(List[Int]([1,2,3])).tap_each(Key(0,seen)).get(),[1,2,3])
    assert_equal(piped(9).tap(Key(0,seen)).get(),9)
    assert_equal(pipeline(9).tap(Key(0,seen)).get(),9)
    seen[].clear()
    comptime Reader=ReaderT[ListFamily,Int]
    var pending=pipeline[Reader](Reader.pure(7)).pair_with(Key(0,seen)).get()
    assert_equal(len(seen[]),0)
    var result=run[Reader](pending^,0)
    assert_equal(result,[(7,8)])
    assert_equal(seen[],[8])
    var abandoned=pipeline[Reader](Reader.pure(9)).tap_each(Key(0,seen)).get()
    _=abandoned^
    assert_equal(seen[],[8])
    assert_equal(piped(17).tap(Once(seen)).get(),17)
    assert_equal(pipeline(19).tap(Once(seen)).get(),19)
    assert_equal(seen[],[8,17,19])
