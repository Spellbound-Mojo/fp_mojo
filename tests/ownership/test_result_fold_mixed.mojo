"""Mixed folds keep skipped captures, payload moves and native errors exact."""
from fp.data import Result,Ok,Err
from fp.callables import Unary,BorrowCallable,mut_ref
from test_result_fold_receivers import Shared,Mutable
from algebra_support.result_ownership import Token,trace
from std.testing import assert_equal


def read_token(value:Token) raises Token -> Token:
    value.trace[].calls+=1
    if value.trace[].factories: raise Token(7,value.trace)
    return Token(1,value.trace)


def own_token(var value:Token) raises Token -> Token:
    return read_token(value)


def branch[borrowed:Bool,native_ok:Bool,receiver:Int](ok:Bool,fail:Bool) raises:
    var state=trace()
    state[].factories=Int(fail)
    var outcome:Result[Token,Token]
    comptime if receiver==0:
        var handler=Shared(Token(5,state),fail)
        comptime if borrowed:
            var source=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
            try:
                comptime if native_ok: outcome=Ok(source.fold(read_token,handler))
                else: outcome=Ok(source.fold(handler,read_token))
            except error:
                comptime assert type_of(error)==Token
                outcome=Err(error^)
            assert_equal(state[].drops[2],0)
            assert_equal(source.is_ok(),ok)
            _=source^
        else:
            var source=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
            try:
                comptime if native_ok: outcome=Ok(source^.fold_owned(own_token,handler))
                else: outcome=Ok(source^.fold_owned(handler,own_token))
            except error:
                comptime assert type_of(error)==Token
                outcome=Err(error^)
        assert_equal(state[].drops[5],0)
        _=handler^
    elif receiver==1:
        var handler=Mutable(Token(5,state),fail,0)
        comptime if borrowed:
            var source=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
            try:
                comptime if native_ok: outcome=Ok(source.fold(read_token,handler^))
                else: outcome=Ok(source.fold(handler^,read_token))
            except error:
                comptime assert type_of(error)==Token
                outcome=Err(error^)
            assert_equal(state[].drops[2],0)
            assert_equal(source.is_ok(),ok)
            _=source^
        else:
            var source=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
            try:
                comptime if native_ok: outcome=Ok(source^.fold_owned(own_token,handler^))
                else: outcome=Ok(source^.fold_owned(handler^,own_token))
            except error:
                comptime assert type_of(error)==Token
                outcome=Err(error^)
    else:
        var handler=Mutable(Token(5,state),fail,0)
        comptime if borrowed:
            var source=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
            try:
                comptime if native_ok: outcome=Ok(source.fold(read_token,mut_ref(handler)))
                else: outcome=Ok(source.fold(mut_ref(handler),read_token))
            except error:
                comptime assert type_of(error)==Token
                outcome=Err(error^)
            assert_equal(state[].drops[2],0)
            assert_equal(source.is_ok(),ok)
            _=source^
        else:
            var source=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
            try:
                comptime if native_ok: outcome=Ok(source^.fold_owned(own_token,mut_ref(handler)))
                else: outcome=Ok(source^.fold_owned(mut_ref(handler),own_token))
            except error:
                comptime assert type_of(error)==Token
                outcome=Err(error^)
        assert_equal(state[].drops[5],0)
        assert_equal(handler.calls,Int(ok!=native_ok))
        _=handler^
    assert_equal(state[].drops[2],1)
    assert_equal(state[].calls,1)
    assert_equal(outcome.is_err(),fail)
    assert_equal(state[].drops[5],1)
    _=outcome^
    assert_equal(state[].drops[1],Int(not fail))
    assert_equal(state[].drops[7],Int(fail))


@fieldwise_init
struct Identity[o:ImmOrigin](Unary,BorrowCallable):
    comptime Arg=Span[Int,Self.o]
    comptime Payload=Self.Arg
    comptime Out=Self.Arg
    comptime Result=Self.Arg
    def call(self,var value:Self.Arg)->Self.Arg: return value
    def invoke(self,ref value:Self.Arg)->Self.Arg: return value


def view[o:ImmOrigin](value:Span[Int,o]) raises Span[Int,o] -> Span[Int,o]:
    if value[0]<0: raise value
    return value


def external[owned:Bool,native_ok:Bool](owner:List[Int]) -> Result[Span[Int,origin_of(owner)],Span[Int,origin_of(owner)]]:
    var callback=Identity[origin_of(owner)]()
    var source=Result[Span[Int,origin_of(owner)],Span[Int,origin_of(owner)]](Ok(Span(owner))) if native_ok else Result[Span[Int,origin_of(owner)],Span[Int,origin_of(owner)]](Err(Span(owner)))
    try:
        comptime if owned:
            comptime if native_ok: return Ok(source^.fold_owned(view[origin_of(owner)],callback))
            else: return Ok(source^.fold_owned(callback,view[origin_of(owner)]))
        else:
            comptime if native_ok: return Ok(source.fold(view[origin_of(owner)],callback))
            else: return Ok(source.fold(callback,view[origin_of(owner)]))
    except error:
        comptime assert type_of(error)==Span[Int,origin_of(owner)]
        return Err(error)


def main() raises:
    comptime for borrowed in range(2):
        comptime for native_ok in range(2):
            comptime for receiver in range(3):
                for ok in [False,True]:
                    for fail in [False,True]: branch[Bool(borrowed),Bool(native_ok),receiver](ok,fail)
    for sign in [-1,1]:
        var owner:List[Int]=[sign,7]
        comptime for owned in range(2):
            comptime for native_ok in range(2):
                var result=external[Bool(owned),Bool(native_ok)](owner)
                assert_equal(result.is_err(),sign<0)
                if sign<0:
                    var returned=result^.swap().get_or(Span(owner))
                    assert_equal(Pointer(to=returned[0])==Pointer(to=owner[0]),True)
                else:
                    var returned=result^.get_or(Span(owner))
                    assert_equal(Pointer(to=returned[0])==Pointer(to=owner[0]),True)
