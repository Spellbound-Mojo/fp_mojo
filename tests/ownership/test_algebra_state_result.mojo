"""Move-only state, callbacks, stored failures and native exceptions keep ownership."""
from fp.algebra import pure, flat_map, ResultFamily, IdentityFamily
from fp.effects import State, StateT, ResultT, run, lift
from fp.callables import OnceUnary
from algebra_support import split_pair
from fp.data import Result, Ok, Err
from fp._internal.errors import _propagate_error
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal
from test_attempt_once import Trace, Token

comptime Base[retain:Bool] = StateT[IdentityFamily if retain else ResultFamily[Token[2]],Token[0]]
comptime Stack[retain:Bool] = ResultT[State[Token[0]],Token[2]] if retain else Base[False]
comptime Data = Result[Int,Token[2]]
comptime Source[retain:Bool] = State[Token[0]].Pure[Data] if retain else Base[False].Lifted[Data]

def source[retain:Bool](var value:Data)->Source[retain]:
    comptime if retain:
        return rebind_var[Source[retain]](pure[State[Token[0]]](value^))
    else:
        return rebind_var[Source[retain]](lift[Base[False]](value^))

@fieldwise_init
struct Next[retain:Bool](OnceUnary):
    var capture:Token[1]
    var fail:Bool
    comptime I = Stack[Self.retain]
    comptime Arg = Int
    comptime Out = Self.I.Pure[Int]
    comptime Error = Token[3]
    def call_once(deinit self,var argument:Int) raises Token[3] -> Self.Out:
        self.capture.trace[].calls+=1
        var value=argument+self.capture.value
        if self.fail:
            raise Token[3](value,self.capture.trace)
        try:
            return pure[Self.I](value)
        except error:
            comptime assert type_of(error)==Never
            _propagate_error[Token[3]](error^)

def check[retain:Bool]() raises:
    comptime I=Stack[retain]
    comptime C=I.Bound[Source[retain],Next[retain]]
    comptime Out=Tuple[Data,Token[0]] if retain else Result[Tuple[Int,Token[0]],Token[2]]
    for stored_failure in [False,True]:
        for native_failure in [False,True]:
            var trace=ArcPointer(Trace(0,SIMD[DType.int64,4](0)))
            var data=Data(Err(Token[2](9,trace))) if stored_failure else Data(Ok(3))
            var computation:C
            try:
                computation=flat_map[I](Next[retain](Token[1](10,trace),native_failure),source[retain](data^))
            except error:
                comptime assert type_of(error)==Never
                _propagate_error[Never](error^)
            assert_equal(trace[].calls,0)
            assert_equal(trace[].drops[1],0)
            var caught=False
            var output=Optional[Out]()
            try:
                var value=run[Base[retain]](computation^,Token[0](7,trace))
                comptime assert type_of(value)==Out
                output=Optional(rebind_var[Out](value^))
            except error:
                comptime assert type_of(error)==Token[3]
                caught=True
                var failure=rebind_var[Token[3]](error^)
                assert_equal(failure.value,13)
            assert_equal(caught,not stored_failure and native_failure)
            assert_equal(trace[].calls,Int(not stored_failure))
            assert_equal(trace[].drops[1],1)
            assert_equal(Int(trace[].drops[0]),Int(caught or (stored_failure and not retain)))
            assert_equal(trace[].drops[2],0)
            assert_equal(Int(trace[].drops[3]),Int(caught))
            if output:
                var result:Data
                var state=Optional[Token[0]]()
                comptime if retain:
                    var first=Optional[Data]()
                    split_pair(rebind_var[Tuple[Data,Token[0]]](output.take()),first,state)
                    result=first.take()
                else:
                    var native=rebind_var[Result[Tuple[Int,Token[0]],Token[2]]](output.take())
                    try:
                        var first=Optional[Int]()
                        split_pair(native^.raise_on_err(),first,state)
                        result=Data(Ok(first.take()))
                    except failure:
                        result=Data(Err(failure^))
                assert_equal(result.is_err(),stored_failure)
                if state:
                    assert_equal(state.value().value,7)
                var number:Int
                try:
                    number=result^.raise_on_err()
                except failure:
                    number=failure.value
                assert_equal(number,9 if stored_failure else 13)
                _=state^
            assert_equal(trace[].drops[0],1)
            assert_equal(Int(trace[].drops[2]),Int(stored_failure))

def main() raises:
    check[True]()
    check[False]()
    print("State/Result ownership: consuming callbacks, retained/discarded state, exact move-only exceptions")
