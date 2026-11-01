"""Reusable lazy factories retain captures through skipped, returned and raised paths."""
from fp.callables import Thunk
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from test_attempt_once_receivers import Shared
from algebra_support.result_ownership import Token,trace
from std.testing import assert_equal


def retained[route:Int](present:Bool,fail:Bool) raises:
    var state=trace()
    var factory=Shared(Token(6,state),fail)
    for count in range(1,3):
        var outcome:Result[Token,Token]
        try:
            comptime if route<2:
                var source=Result[Token,Token](Ok(Token(2,state))) if present else Result[Token,Token](Err(Token(2,state)))
                comptime if route==0: outcome=Ok(source^.get_or_else(factory))
                else: outcome=Ok(pipeline(source^).get_or_else(factory))
            else:
                var source=Optional(Token(2,state)) if present else Optional[Token]()
                comptime if route==2: outcome=Ok(pipeline(source^).get_or_else(factory))
                else: outcome=pipeline(source^).to_result(factory).get()
        except error:
            comptime assert type_of(error)==Token
            outcome=Err(error^)
        assert_equal(outcome.is_err(),not present and (fail or route==3))
        assert_equal(state[].calls,count*Int(not present))
        assert_equal(state[].drops[6],0)
        assert_equal(state[].drops[2],count-Int(present) if route<2 or present else 0)
        _=outcome^
        assert_equal(state[].drops[2],count if route<2 or present else 0)
        assert_equal(state[].drops[1],count*Int(not present and not fail))
        assert_equal(state[].drops[7],count*Int(not present and fail))
    assert_equal(factory.fail,fail)
    _=factory^
    assert_equal(state[].drops[6],1)


@fieldwise_init
struct External[o:ImmOrigin](Thunk):
    comptime Out=Span[Int,Self.o]
    comptime Error=Span[Int,Self.o]
    var values:Self.Out
    var fail:Bool
    def call(self) raises Self.Error -> Self.Out:
        if self.fail: raise self.values
        return self.values


def external[route:Int](owner:List[Int],fail:Bool) -> Result[Span[Int,origin_of(owner)],Span[Int,origin_of(owner)]]:
    var factory=External(Span(owner),fail)
    try:
        comptime if route==0: return Ok(Result[Span[Int,origin_of(owner)],Int](Err(0)).get_or_else(factory))
        elif route==1: return Ok(pipeline(Result[Span[Int,origin_of(owner)],Int](Err(0))).get_or_else(factory))
        elif route==2: return Ok(pipeline(Optional[Span[Int,origin_of(owner)]]()).get_or_else(factory))
        else: return pipeline(Optional[Span[Int,origin_of(owner)]]()).to_result(factory).get()
    except error:
        comptime assert type_of(error)==Span[Int,origin_of(owner)]
        return Err(error)


def main() raises:
    comptime for route in range(4):
        for present in [False,True]:
            for fail in [False,True]: retained[route](present,fail)
    var owner:List[Int]=[7,11]
    comptime for route in range(4):
        for fail in [False,True]:
            var result=external[route](owner,fail)
            assert_equal(result.is_err(),fail or route==3)
            if fail or route==3:
                var view=result^.swap().get_or(Span(owner))
                assert_equal(Pointer(to=view[0])==Pointer(to=owner[0]),True)
            else:
                var view=result^.get_or(Span(owner))
                assert_equal(Pointer(to=view[0])==Pointer(to=owner[0]),True)
