"""Ordinary folds preserve shared captures and destroy only transferred handlers."""
from fp.callables import mut_ref
from fp.data import Result,Ok,Err
from test_result_fold_receivers import Shared,Mutable,External
from algebra_support.result_ownership import Token,Trace,trace
from std.memory import ArcPointer
from std.testing import assert_equal


def mixed[borrowed:Bool,owned_ok:Bool](ok:Bool,fail:Bool) raises:
    var state=trace()
    var shared=Shared(Token(5,state),fail)
    var owned=Mutable(Token(6,state),fail,0)
    var subject=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
    var outcome:Result[Token,Token]
    comptime if borrowed:
        try:
            comptime if owned_ok: outcome=Ok(subject.fold(owned^,shared))
            else: outcome=Ok(subject.fold(shared,owned^))
        except error:
            comptime assert type_of(error)==Token
            outcome=Err(error^)
        assert_equal(state[].drops[2],0)
        assert_equal(subject.is_ok(),ok)
        _=subject^
    else:
        try:
            comptime if owned_ok: outcome=Ok(subject^.fold_owned(owned^,shared))
            else: outcome=Ok(subject^.fold_owned(shared,owned^))
        except error:
            comptime assert type_of(error)==Token
            outcome=Err(error^)
    assert_equal(outcome.is_err(),fail)
    assert_equal(state[].calls,1)
    assert_equal(state[].drops[2],1)
    assert_equal(state[].drops[5],0)
    assert_equal(state[].drops[6],1)
    _=shared^
    assert_equal(state[].drops[5],1)
    _=outcome^
    assert_equal(state[].drops[1],Int(not fail))
    assert_equal(state[].drops[7],Int(fail))


def shared_pair[borrowed:Bool](ok:Bool,fail:Bool) raises:
    var state=trace()
    var yes=Shared(Token(5,state),fail)
    var no=Shared(Token(6,state),fail)
    var subject=Result[Token,Token](Ok(Token(2,state))) if ok else Result[Token,Token](Err(Token(2,state)))
    var outcome:Result[Token,Token]
    comptime if borrowed:
        try: outcome=Ok(subject.fold(yes,no))
        except error: outcome=Err(error^)
        assert_equal(state[].drops[2],0)
        assert_equal(subject.is_ok(),ok)
        _=subject^
    else:
        try: outcome=Ok(subject^.fold_owned(yes,no))
        except error: outcome=Err(error^)
    assert_equal(outcome.is_err(),fail)
    assert_equal(state[].calls,1)
    assert_equal(state[].drops[2],1)
    assert_equal(state[].drops[5],0)
    assert_equal(state[].drops[6],0)
    _=yes^
    _=no^
    assert_equal(state[].drops[5],1)
    assert_equal(state[].drops[6],1)
    _=outcome^
    assert_equal(state[].drops[1],Int(not fail))
    assert_equal(state[].drops[7],Int(fail))


def external[consume:Bool](owner:List[Int],state:ArcPointer[Trace],fail:Bool) -> Result[Span[Int,origin_of(owner)],Span[Int,origin_of(owner)]]:
    var yes=External(Span(owner),Token(5,state),fail)
    var no=External(Span(owner),Token(6,state),fail)
    try:
        comptime if consume: return Ok(Result[Int,Int](Ok(4)).fold_owned(yes^,no^))
        else: return Ok(Result[Int,Int](Ok(4)).fold(yes^,no^))
    except error: return Err(error)


def main() raises:
    comptime for borrowed in range(2):
        for ok in [False,True]:
            for fail in [False,True]:
                shared_pair[Bool(borrowed)](ok,fail)
                comptime for owned_ok in range(2): mixed[Bool(borrowed),Bool(owned_ok)](ok,fail)
    var owner:List[Int]=[7,11]
    comptime for consume in range(2):
        for fail in [False,True]:
            var state=trace()
            var result=external[Bool(consume)](owner,state,fail)
            assert_equal(result.is_err(),fail)
            assert_equal(state[].calls,1)
            assert_equal(state[].drops[5],1)
            assert_equal(state[].drops[6],1)
            if fail:
                var view=result^.swap().get_or(Span(owner))
                assert_equal(Pointer(to=view[0])==Pointer(to=owner[0]),True)
            else:
                var view=result^.get_or(Span(owner))
                assert_equal(Pointer(to=view[0])==Pointer(to=owner[0]),True)
