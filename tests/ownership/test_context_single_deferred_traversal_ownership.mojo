from fp.algebra import Applicative,OptionalFamily,ResultFamily,TraverseContract,traverse
from fp.effects import Reader,State,run
from fp.callables import OnceUnary
from fp.data import Result,Ok,Err
from std.builtin.rebind import rebind_var,rebind,downcast
from fp.effects import StateFamily,ReaderFamily
from fp._internal.errors import _propagate_error
from std.memory import ArcPointer
from std.testing import assert_equal
from test_applicative_error_ownership import AEOOwner as Owner

@fieldwise_init
struct Produce[I:Applicative](OnceUnary):
    var capture:Owner
    var calls:ArcPointer[Int]
    var fail:Bool
    comptime Arg=Owner
    comptime Out=Self.I.Pure[Owner]
    comptime Error=Int
    def call_once(deinit self,var value:Owner) raises Int ->Self.Out:
        self.calls[]+=1
        if self.fail:raise 71
        value.value+=self.capture.value
        return Self.I.pure(value^)

def check[is_state:Bool,is_result:Bool]() raises:
    comptime I=State[Owner] if is_state else Reader[Int]
    comptime S=ResultFamily[Owner] if is_result else OptionalFamily
    comptime V=S.Pure[Owner]
    comptime assert TraverseContract[S,I,V,Produce[I]].Compatible
    for skip in [False,True]:
        for fail in [False,True]:
            for discard in [False,True]:
                var inputs=ArcPointer(0)
                var captures=ArcPointer(0)
                var errors=ArcPointer(0)
                var states=ArcPointer(0)
                var calls=ArcPointer(0)
                var source:V
                comptime if is_result:
                    source=rebind_var[V](Result[Owner,Owner](Err(Owner(9,errors))) if skip else Result[Owner,Owner](Ok(Owner(3,inputs))))
                else:
                    source=rebind_var[V](Optional[Owner]() if skip else Optional(Owner(3,inputs)))
                var caught=0
                comptime Pending=TraverseContract[S,I,V,Produce[I]].Out
                var pending=Optional[Pending]()
                try:
                    pending=Optional(traverse[S,I](Produce[I](Owner(10,captures),calls,fail),source^))
                except error:
                    comptime assert type_of(error)==Int
                    caught=rebind_var[Int](error^)
                assert_equal(calls[],Int(not skip))
                assert_equal(captures[],1)
                assert_equal(inputs[],Int(not skip and fail))
                assert_equal(errors[],0)
                if pending:
                    if discard:_=pending.take()
                    else:
                        comptime if is_state:
                            comptime G=downcast[I,StateFamily]
                            comptime assert G.CarrierCompatible[Pending]
                            try:_=run[G](pending.take(),rebind_var[G.StateType](Owner(0,states)))
                            except error:
                                comptime assert type_of(error)==Never
                                _propagate_error[Never](error^)
                        else:
                            comptime G=downcast[I,ReaderFamily]
                            comptime assert G.CarrierCompatible[Pending]
                            var env=0
                            comptime assert G.Environment==Int
                            comptime assert G.RunCompatible[Pending,origin_of(env)]
                            try:_=run[G](pending.take(),rebind[G.Environment](env))
                            except error:
                                comptime assert type_of(error)==Never
                                _propagate_error[Never](error^)
                assert_equal(caught,71 if not skip and fail else 0)
                assert_equal(calls[],Int(not skip))
                assert_equal(captures[],1)
                assert_equal(inputs[],Int(not skip))
                assert_equal(errors[],Int(is_result and skip))
                assert_equal(states[],Int(is_state and not discard and (skip or not fail)))

def main() raises:
    check[False,False]()
    check[False,True]()
    check[True,False]()
    check[True,True]()
