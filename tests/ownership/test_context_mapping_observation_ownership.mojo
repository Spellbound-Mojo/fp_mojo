"""Mapping-only observers borrow move-only errors and preserve state cleanup."""
from fp.algebra import ApplicativeError, ErrorMapping, ResultFamily, ListFamily
from fp.callables import BorrowOnceCallable, OnceUnary
from fp.effects import StateT, ResultT, action, run
from fp.functions import pipeline
from fp.data import Result, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_transport_error_mapping_ownership import Owner, Step

@fieldwise_init
struct Observe(BorrowOnceCallable):
    var capture: Owner
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Payload = String
    comptime Result = Int
    comptime Failure = Int
    def invoke_once(deinit self,ref error: String) raises Int -> Int:
        self.calls[] += 1
        if self.fail: raise 785
        return error.byte_length()

def state_case(source_drops: ArcPointer[Int], observer_drops: ArcPointer[Int], state_drops: ArcPointer[Int], source_calls: ArcPointer[Int], observer_calls: ArcPointer[Int], observed: ArcPointer[Int], mode: Int, fail: Bool, execute: Bool) -> Int:
    comptime S=StateT[ResultFamily[String],Owner]
    comptime assert conforms_to(S,ErrorMapping) and not conforms_to(S,ApplicativeError)
    var source=action[S,Int](Step(Owner(1,source_drops),source_calls,observed,mode))
    var pending=pipeline[S](source^).tap_err(Observe(Owner(2,observer_drops),observer_calls,fail))
    comptime assert type_of(pending).I == S
    comptime assert not conforms_to(type_of(pending),Copyable)
    if not execute:return 0
    try:
        var result=run[S](pending^.get(),Owner(11,state_drops))
        if result.is_err():
            if result._err().value != "old":return -1
            return 3
        return result._ok().value[0]+result._ok().value[1].value
    except error:
        comptime assert type_of(error)==Int
        return error

@fieldwise_init
struct ObserveOwned(BorrowOnceCallable):
    var capture: Owner
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Payload=Owner
    comptime Result=Owner
    comptime Failure=Int
    def invoke_once(deinit self,ref error:Owner) raises Int -> Owner:
        self.calls[]+=1
        if error.value != 9:raise -1
        if self.fail:raise 786
        return self.capture^

def owned_errors() raises:
    comptime S=StateT[ResultFamily[Owner],Owner]
    for execute in range(2):
        for fails in range(2):
            var errors=ArcPointer(0)
            var captures=ArcPointer(0)
            var states=ArcPointer(0)
            var calls=ArcPointer(0)
            var pending=pipeline[S](S.lift(Result[Int,Owner](Err(Owner(9,errors))))).tap_err(ObserveOwned(Owner(2,captures),calls,Bool(fails))).get()
            assert_equal(errors[],0)
            assert_equal(captures[],0)
            if execute:
                var code=0
                try:
                    var result=run[S](pending^,Owner(3,states))
                    if errors[] != 0 or result._err().value.value != 9:raise -1
                except error:
                    comptime assert type_of(error)==Int
                    code=error
                assert_equal(code,786 if fails else 0)
            else:_=pending^
            assert_equal(errors[],1)
            assert_equal(captures[],1)
            assert_equal(states[],execute)
            assert_equal(calls[],execute)

@fieldwise_init
struct Branches(OnceUnary):
    comptime Arg=Owner
    comptime Out=List[Result[Tuple[Int,Owner],String]]
    def call_once(deinit self,var state:Owner)->Self.Out:
        return [Result[Tuple[Int,Owner],String](Err(String("first"))),Result[Tuple[Int,Owner],String](Err(String("second")))]

def branched() raises:
    comptime S=StateT[ResultT[ListFamily,String],Owner]
    comptime assert conforms_to(S,ErrorMapping) and not conforms_to(S,ApplicativeError)
    var calls=0
    var drops=ArcPointer(0)
    def observe(error:String) {mut calls}:
        calls+=1
    var pending=pipeline[S](action[S,Int](Branches())).tap_err(observe).get()
    assert_equal(calls,0)
    var values=run[S](pending^,Owner(0,drops))
    assert_equal(calls,2)
    assert_equal(drops[],1)
    assert_equal(len(values),2)
    assert_equal(values[0]._err().value,"first")
    assert_equal(values[1]._err().value,"second")


def main() raises:
    for execute in range(2):
        for mode in range(3):
            for fails in range(2):
                var source_drops=ArcPointer(0)
                var observer_drops=ArcPointer(0)
                var state_drops=ArcPointer(0)
                var source_calls=ArcPointer(0)
                var observer_calls=ArcPointer(0)
                var observed=ArcPointer(0)
                var value=state_case(source_drops,observer_drops,state_drops,source_calls,observer_calls,observed,mode,Bool(fails),Bool(execute))
                assert_equal(value,0 if execute==0 else 42 if mode==0 else 784 if mode==2 else 785 if fails else 3)
                assert_equal(source_drops[],1)
                assert_equal(observer_drops[],1)
                assert_equal(state_drops[],execute)
                assert_equal(source_calls[],execute)
                assert_equal(observer_calls[],1 if execute and mode==1 else 0)
                assert_equal(observed[],21 if execute else 0)
    owned_errors()
    branched()
