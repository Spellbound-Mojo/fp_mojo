"""Single-execution layers move owners and clean up skipped or abandoned work."""
from fp.algebra import map2_lazy
from fp.effects import Reader, OptionalT, ResultT, run
from fp.callables import OnceBinary, OnceThunk
from fp.data import Result, Err
from test_applicative_error_ownership import AEOOwner as Owner
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Combine(OnceBinary):
    var capture:Owner
    var calls:ArcPointer[Int]
    var fail:Bool
    comptime First=Owner
    comptime Second=Owner
    comptime Out=Owner
    comptime Error=Int
    def call_once(deinit self,var first:Owner,var second:Owner) raises Int ->Owner:
        self.calls[]+=1
        if self.fail:raise 802
        first.value+=second.value+self.capture.value
        return first^

@fieldwise_init
struct Produce[T:Movable & Deinitable](OnceThunk):
    var value:Self.T
    var capture:Owner
    var calls:ArcPointer[Int]
    var fail:Bool
    comptime Out=Self.T
    comptime Error=Int
    def call_once(deinit self) raises Int ->Self.Out:
        self.calls[]+=1
        if self.fail:raise 801
        return self.value^

def optional_scenario(left_drops:ArcPointer[Int],right_drops:ArcPointer[Int],combine_drops:ArcPointer[Int],factory_drops:ArcPointer[Int],combine_calls:ArcPointer[Int],factory_calls:ArcPointer[Int],execute:Bool,skip:Bool,failure:Int)->Int:
    comptime Base=Reader[Int]
    comptime I=OptionalT[Base]
    var left:I.Pure[Owner]
    if skip:
        left=Base.pure(Optional[Owner]())
    else:left=I.pure(Owner(1,left_drops))
    var pending=map2_lazy[I](left^,Produce(I.pure(Owner(3,right_drops)),Owner(4,factory_drops),factory_calls,failure==1),Combine(Owner(2,combine_drops),combine_calls,failure==2))
    comptime assert not conforms_to(type_of(pending),Copyable)
    if not execute:return 0
    try:_=run[Base](pending^,0)
    except error:
        comptime assert type_of(error)==Int
        return error
    return 0

def result_scenario(left_drops:ArcPointer[Int],right_drops:ArcPointer[Int],combine_drops:ArcPointer[Int],factory_drops:ArcPointer[Int],combine_calls:ArcPointer[Int],factory_calls:ArcPointer[Int],execute:Bool,skip:Bool,failure:Int)->Int:
    comptime Base=Reader[Int]
    comptime I=ResultT[Base,String]
    var left:I.Pure[Owner]
    if skip:
        left=Base.pure(Result[Owner,String](Err(String("skip"))))
    else:left=I.pure(Owner(1,left_drops))
    var pending=map2_lazy[I](left^,Produce(I.pure(Owner(3,right_drops)),Owner(4,factory_drops),factory_calls,failure==1),Combine(Owner(2,combine_drops),combine_calls,failure==2))
    comptime assert not conforms_to(type_of(pending),Copyable)
    if not execute:return 0
    try:_=run[Base](pending^,0)
    except error:
        comptime assert type_of(error)==Int
        return error
    return 0

def check(callback:def(ArcPointer[Int],ArcPointer[Int],ArcPointer[Int],ArcPointer[Int],ArcPointer[Int],ArcPointer[Int],Bool,Bool,Int) thin -> Int) raises:
    for execute in [False,True]:
        for skip in [False,True]:
            for failure in range(3):
                var left=ArcPointer(0)
                var right=ArcPointer(0)
                var combine=ArcPointer(0)
                var factory=ArcPointer(0)
                var combine_calls=ArcPointer(0)
                var factory_calls=ArcPointer(0)
                var code=callback(left,right,combine,factory,combine_calls,factory_calls,execute,skip,failure)
                assert_equal(code,800+failure if execute and not skip and failure else 0)
                assert_equal(left[],0 if skip else 1)
                assert_equal(right[],1)
                assert_equal(combine[],1)
                assert_equal(factory[],1)
                assert_equal(factory_calls[],Int(execute and not skip))
                assert_equal(combine_calls[],Int(execute and not skip and failure!=1))

def main() raises:
    check(optional_scenario)
    check(result_scenario)
