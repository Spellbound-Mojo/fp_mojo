"""A deferred traversal consumes source items, capture, state and errors once."""
from fp.algebra import traverse, ListFamily, ResultFamily, Monad
from fp.effects import StateT, action, run
from fp.callables import MutableUnary, OnceUnary
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal
from test_attempt_once import Trace, Token
from fp._internal.errors import _propagate_error

comptime Data=Result[Tuple[Int,Token[1]],Token[3]]

@fieldwise_init
struct Step(OnceUnary):
    var item:Token[0]
    var failure:Int
    comptime Arg=Token[1]
    comptime Out=Data
    comptime Error=Token[3]
    def call_once(deinit self,var state:Token[1]) raises Token[3] ->Data:
        state.value+=self.item.value
        if self.item.value==3:
            if self.failure==1:
                return Data(Err(Token[3](203,self.item.trace)))
            if self.failure==2:
                raise Token[3](203,self.item.trace)
        return Data(Ok(Tuple(state.value,state^)))

comptime Endpoint[M:Monad]=type_of(action[StateT[M,Token[1]],Int](Step(Token[0](0,ArcPointer(Trace(0,SIMD[DType.int64,4](0)))),0)))

@fieldwise_init
struct Produce[M:Monad](MutableUnary):
    comptime I=StateT[Self.M,Token[1]]
    var capture:Token[2]
    var failure:Int
    comptime Arg=Token[0]
    comptime Out=Endpoint[Self.M]
    comptime Error=Token[3]
    def call_mut(mut self,var item:Token[0]) raises Token[3] ->Endpoint[Self.M]:
        self.capture.trace[].calls+=1
        if item.value==3 and self.failure==3:
            raise Token[3](103,item.trace)
        return action[Self.I,Int](Step(item^,self.failure))

def check_traversal_ownership[M:Monad]() raises:
    comptime I=StateT[M,Token[1]]
    for failure in range(4):
        var trace=ArcPointer(Trace(0,SIMD[DType.int64,4](0)))
        var items=List[Token[0]]()
        for item in range(1,6):
            items.append(Token[0](item,trace))
        comptime assert ListFamily.TraverseError[I,List[Token[0]],Produce[M]]==Never
        var computation:ListFamily.Traversed[I,List[Token[0]],Produce[M]]
        try:
            computation=traverse[ListFamily,I](Produce[M](Token[2](0,trace),failure),items^)
        except error:
            comptime assert type_of(error)==Never
            _propagate_error[Never](error^)
        assert_equal(trace[].calls,0)
        for index in range(4):
            assert_equal(trace[].drops[index],0)
        var output=Optional[Result[Tuple[List[Int],Token[1]],Token[3]]]()
        var native_code=0
        try:
            var value=run[I](computation^,Token[1](10,trace))
            comptime assert type_of(value)==Result[Tuple[List[Int],Token[1]],Token[3]]
            output=Optional(rebind_var[Result[Tuple[List[Int],Token[1]],Token[3]]](value^))
        except error:
            comptime assert type_of(error)==Token[3]
            native_code=rebind[Token[3]](error).value
        assert_equal(native_code,103 if failure==3 else 203 if failure==2 else 0)
        assert_equal(trace[].calls,5 if failure==0 else 3)
        assert_equal(trace[].drops[0],5)
        assert_equal(trace[].drops[2],1)
        assert_equal(Int(trace[].drops[1]),Int(failure!=0))
        assert_equal(Int(trace[].drops[3]),Int(failure>=2))
        if output:
            var result=output.take()
            assert_equal(result.is_err(),failure==1)
            var stored_code=0
            var final_state=0
            var length=0
            try:
                var pair=result^.raise_on_err()
                final_state=pair[1].value
                length=len(pair[0])
            except error:
                stored_code=error.value
            assert_equal(stored_code,203 if failure==1 else 0)
            assert_equal(final_state,25 if failure==0 else 0)
            assert_equal(length,5 if failure==0 else 0)
        assert_equal(trace[].drops[1],1)
        assert_equal(Int(trace[].drops[3]),Int(failure!=0))
    print("deferred traversal ownership: move-only source, state, callback and native/stored errors")


def main() raises:
    check_traversal_ownership[ResultFamily[Token[3]]]()
