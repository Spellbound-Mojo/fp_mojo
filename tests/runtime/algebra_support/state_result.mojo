"""Native endpoints shared by the two State/Result order checks."""
from fp.algebra import IdentityFamily, ResultFamily
from fp.effects import State, StateT, ResultT, action
from fp.callables import OnceUnary, OnceBinary, OnceThunk
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from algebra_support import split_pair
from std.testing import assert_equal

comptime Base[retain:Bool] = StateT[IdentityFamily if retain else ResultFamily[Int],Int]
comptime Stack[retain:Bool] = ResultT[State[Int],Int] if retain else Base[False]

@fieldwise_init
struct Step[retain:Bool](OnceUnary):
    var trace:ArcPointer[List[Int]]
    var marker:Int
    var delta:Int
    var failure:Int
    comptime Output = Tuple[Result[Int,Int],Int] if Self.retain else Result[Tuple[Int,Int],Int]
    comptime Arg = Int
    comptime Out = Self.Output
    comptime Error = Error
    def call_once(deinit self,var initial:Int) raises -> Self.Output:
        var state=initial+self.delta
        self.trace[].append(self.marker)
        if self.failure==2:
            raise Error("native action failure")
        comptime if Self.retain:
            var result=Result[Int,Int](Err(self.marker)) if self.failure==1 else Result[Int,Int](Ok(state))
            return rebind_var[Self.Output](Tuple(result^,state))
        else:
            if self.failure==1:
                return rebind_var[Self.Output](Result[Tuple[Int,Int],Int](Err(self.marker)))
            return rebind_var[Self.Output](Result[Tuple[Int,Int],Int](Ok(Tuple(state,state))))

comptime Endpoint[retain:Bool] = type_of(action[Base[retain],Result[Int,Int] if retain else Int](Step[retain](ArcPointer(List[Int]()),0,0,0)))

def step[retain:Bool](trace:ArcPointer[List[Int]],marker:Int,delta:Int,failure:Int=0)->Endpoint[retain]:
    return action[Base[retain],Result[Int,Int] if retain else Int](Step[retain](trace,marker,delta,failure))

@fieldwise_init
struct Next[retain:Bool](OnceUnary):
    var trace:ArcPointer[List[Int]]
    var failure:Int
    comptime Arg = Int
    comptime Out = Endpoint[Self.retain]
    comptime Error = Error
    def call_once(deinit self,var value:Int) raises -> Endpoint[Self.retain]:
        self.trace[].append(2)
        if self.failure==3:
            raise Error("native callback failure")
        return step[Self.retain](self.trace,3,value,self.failure)


def assert_output[retain:Bool](var output:Step[retain].Output,number:Int,state:Int,error:Int=0) raises:
    var result:Result[Int,Int]
    var actual_state=state
    comptime if retain:
        var first=Optional[Result[Int,Int]]()
        var second=Optional[Int]()
        split_pair(rebind_var[Tuple[Result[Int,Int],Int]](output^),first,second)
        actual_state=second.take()
        result=first.take()
    else:
        var native=rebind_var[Result[Tuple[Int,Int],Int]](output^)
        try:
            var pair=native^.raise_on_err()
            result=Result[Int,Int](Ok(pair[0]))
            actual_state=pair[1]
        except failure:
            result=Result[Int,Int](Err(failure))
    assert_equal(actual_state,state)
    assert_equal(result.is_err(),error!=0)
    var actual:Int
    try:
        actual=result^.raise_on_err()
    except failure:
        actual=failure
    assert_equal(actual,error if error!=0 else number)


@fieldwise_init
struct Produce[retain:Bool](OnceThunk):
    var trace:ArcPointer[List[Int]]
    var failure:Int
    comptime Out = Endpoint[Self.retain]
    comptime Error = Error
    def call_once(deinit self) raises -> Endpoint[Self.retain]:
        self.trace[].append(2)
        if self.failure==3:
            raise Error("native factory failure")
        return step[Self.retain](self.trace,3,7,self.failure)

@fieldwise_init
struct Combine(OnceBinary):
    var trace:ArcPointer[List[Int]]
    var fail:Bool
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Error
    def call_once(deinit self,var first:Int,var second:Int) raises -> Int:
        self.trace[].append(4)
        if self.fail:
            raise Error("native combination failure")
        return first+second
