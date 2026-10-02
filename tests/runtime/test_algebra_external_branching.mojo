"""Public base binding preserves breadth, inactive branches and prepared values."""
from fp.algebra import ListFamily, traverse
from fp.effects import StateT, OptionalT, action, run
from fp.callables import Unary, OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.external import PublicMonad
from algebra_support import ints
from algebra_support.iterators import Counted

comptime S=StateT[PublicMonad[ListFamily],Int]
comptime Data=List[Tuple[Optional[Int],Int]]

@fieldwise_init
struct Step(Copyable,OnceUnary):
    var item:Int
    var stop_all:Bool
    var calls:ArcPointer[Int]
    comptime Arg=Int
    comptime Out=Data
    def call_once(deinit self,var state:Int)->Data:
        self.calls[]+=1
        var output=Data()
        if self.item==1:
            output.append(Tuple(Optional[Int](),state+100))
            output.append(Tuple(Optional(state+1),state+1))
            output.append(Tuple(Optional(state+10),state+10))
        else:
            var stopped=self.item==3 and (self.stop_all or state<20)
            state+=self.item
            output.append(Tuple(Optional[Int]() if stopped else Optional(state),state))
        return output^

comptime Endpoint=type_of(action[S,Optional[Int]](Step(0,False,ArcPointer(Int(0)))))

@fieldwise_init
struct Produce(Unary):
    var calls:ArcPointer[Int]
    var steps:ArcPointer[Int]
    var stop_all:Bool
    comptime Arg=Int
    comptime Out=Endpoint
    def call(self,var item:Int)->Endpoint:
        self.calls[]+=1
        return action[S,Optional[Int]](Step(item,self.stop_all,self.steps))

def main() raises:
    for count in [0,5]:
        for stop_all in [False,True]:
            var pulls=0
            var calls=ArcPointer(Int(0))
            var steps=ArcPointer(Int(0))
            var computation=traverse[ListFamily,OptionalT[S]](Produce(calls,steps,stop_all),Counted(Pointer(to=pulls),0,count))
            assert_equal(pulls,0)
            assert_equal(calls[],0)
            assert_equal(steps[],0)
            var output=run[S](computation^,10)
            comptime assert type_of(output)==List[Tuple[Optional[List[Int]],Int]]
            assert_equal(len(output),1 if count==0 else 3)
            assert_equal(pulls,1 if count==0 else 3 if stop_all else 6)
            assert_equal(calls[],0 if count==0 else 3 if stop_all else 5)
            assert_equal(steps[],0 if count==0 else 5 if stop_all else 7)
            if count==0:
                assert_equal(output[0][1],10)
                assert_equal(len(output[0][0].value()),0)
            else:
                assert_equal(Bool(output[0][0]),False)
                assert_equal(output[0][1],110)
                assert_equal(Bool(output[1][0]),False)
                assert_equal(output[1][1],16)
                assert_equal(Bool(output[2][0]),not stop_all)
                assert_equal(output[2][1],25 if stop_all else 34)
                if not stop_all:
                    assert_equal(output[2][0].value(),ints(20,22,25,29,34))
    print("external base traversal: one producer per item, branch order, inactive carry")
