"""Shared sequencing retains captures and drops each active or skipped payload once."""
from fp.callables import Thunk
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from algebra_support.result_ownership import Token,trace
from std.testing import assert_equal

@fieldwise_init
struct Factory(Thunk):
    comptime Out=Result[Token,Token]
    comptime Error=Token
    var capture:Token
    var mode:Int
    def call(self) raises Token -> Self.Out:
        self.capture.trace[].calls+=1
        if self.mode==2: raise Token(7,self.capture.trace)
        if self.mode==1: return Err(Token(4,self.capture.trace))
        return Ok(Token(1,self.capture.trace))


def retained[fluent:Bool,keep:Bool](ok:Bool,mode:Int) raises:
    var state=trace()
    var factory=Factory(Token(6,state),mode)
    for count in range(1,3):
        var source=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
        var outcome:Result[Token,Token]
        try:
            comptime if fluent:
                comptime if keep: outcome=pipeline(source^).before(factory).get()
                else: outcome=pipeline(source^).followed_by(factory).get()
            else:
                comptime if keep: outcome=source^.before(factory)
                else: outcome=source^.followed_by(factory)
        except error:
            comptime assert type_of(error)==Token
            outcome=Err(error^)
        assert_equal(outcome.is_err(),not ok or mode!=0)
        assert_equal(state[].calls,count*Int(ok))
        assert_equal(state[].drops[6],0)
        assert_equal(state[].drops[2],count-Int(not ok or (keep and mode==0)))
        assert_equal(state[].drops[1],count*Int(ok and mode==0) if keep else (count-1)*Int(ok and mode==0))
        _=outcome^
        assert_equal(state[].drops[2],count)
        assert_equal(state[].drops[1],count*Int(ok and mode==0))
        assert_equal(state[].drops[4],count*Int(ok and mode==1))
        assert_equal(state[].drops[7],count*Int(ok and mode==2))
    assert_equal(factory.mode,mode)
    _=factory^
    assert_equal(state[].drops[6],1)


@fieldwise_init
struct External[o:ImmOrigin](Thunk):
    comptime Out=Result[Span[Int,Self.o],Int]
    comptime Error=Span[Int,Self.o]
    var values:Span[Int,Self.o]
    var fail:Bool
    def call(self) raises Self.Error -> Self.Out:
        if self.fail:raise self.values
        return Ok(self.values)


def external[fluent:Bool](owner:List[Int],fail:Bool) -> Result[Span[Int,origin_of(owner)],Span[Int,origin_of(owner)]]:
    var factory=External(Span(owner),fail)
    try:
        comptime if fluent: return Ok(pipeline(Result[Int,Int](Ok(4))).followed_by(factory).get_or(Span(owner)))
        else: return Ok(Result[Int,Int](Ok(4)).followed_by(factory).get_or(Span(owner)))
    except error:
        comptime assert type_of(error)==Span[Int,origin_of(owner)]
        return Err(error)


def main() raises:
    comptime for fluent in range(2):
        comptime for keep in range(2):
            for ok in [False,True]:
                for mode in range(3): retained[Bool(fluent),Bool(keep)](ok,mode)
    var owner:List[Int]=[7,11]
    comptime for fluent in range(2):
        for fail in [False,True]:
            var result=external[Bool(fluent)](owner,fail)
            assert_equal(result.is_err(),fail)
            if fail:
                var view=result^.swap().get_or(Span(owner))
                assert_equal(Pointer(to=view[0])==Pointer(to=owner[0]),True)
            else:
                var view=result^.get_or(Span(owner))
                assert_equal(Pointer(to=view[0])==Pointer(to=owner[0]),True)
