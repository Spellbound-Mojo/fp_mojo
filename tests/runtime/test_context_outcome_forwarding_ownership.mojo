"""Outcome sequencing preserves ownership when construction or callbacks raise."""
from std.testing import assert_equal
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from fp.algebra import ApplicativeError, Monad, ResultFamily
from fp.algebra._outcomes import _Redeem, _AttemptTap
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
from test_context_failure_forwarding_ownership import Owner
from test_context_family_ensure import Family
from test_context_family_outcome_selection import ConstructionMonad

@fieldwise_init
struct Handler[P: Movable & Deinitable, effect: Bool](OnceUnary):
    var owner: Owner
    var fail: Bool
    comptime Arg = Self.P
    comptime Out = Result[Owner,String] if Self.effect else Owner
    comptime Error = Int
    def call_once(deinit self, var arg: Self.Arg) raises Int -> Self.Out:
        self.owner.trace[] += "h" + String(self.owner.id)
        if self.fail: raise 83
        var value = Owner(4,self.owner.trace)
        comptime if Self.effect:
            return rebind_var[Self.Out](Result[Owner,String](Ok(value^)))
        else:
            return rebind_var[Self.Out](value^)

@fieldwise_init
struct Observer(BorrowOnceCallable):
    var owner: Owner
    var mode: Int
    comptime Payload = Result[Owner,String]
    comptime Result = Result[Int,String]
    comptime Failure = Int
    def invoke_once(deinit self, ref outcome: Self.Payload) raises Int -> Self.Result:
        self.owner.trace[] += "o"
        if self.mode == 2: raise 84
        if self.mode == 1: return Err(String("observer"))
        return Ok(0)

def redeem[I: ApplicativeError & Monad, effect: Bool](success: Bool, fail: Bool) -> String:
    var trace = ArcPointer(String())
    var source: Result[Owner,String]
    if success: source = Ok(Owner(1,trace))
    else: source = Err(String("old"))
    comptime Operation = _Redeem[I,Result[Owner,String],Handler[Owner,effect],Handler[String,effect],effect]
    comptime assert Operation.Error == Int
    var code = 0
    try:
        var result = Operation.apply(source^,Handler[Owner,effect](Owner(2,trace),fail),Handler[String,effect](Owner(3,trace),fail))
        _ = result^
    except error:
        comptime assert type_of(error) == Int
        code = rebind_var[Int](error^)
    return String(code) + ":" + trace[]

def tap[I: ApplicativeError & Monad](success: Bool, mode: Int) -> String:
    var trace = ArcPointer(String())
    var source: Result[Owner,String]
    if success: source = Ok(Owner(1,trace))
    else: source = Err(String("old"))
    comptime Operation = _AttemptTap[I,Result[Owner,String],Observer]
    comptime assert Operation.Error == Int
    var code = 0
    try:
        var result = Operation.apply(source^,Observer(Owner(2,trace),mode))
        _ = result^
    except error:
        comptime assert type_of(error) == Int
        code = rebind_var[Int](error^)
    return String(code) + ":" + trace[]

def main() raises:
    assert_equal(redeem[ResultFamily[String],False](False,False),"0:h3324")
    assert_equal(redeem[ResultFamily[String],True](False,False),"0:h3324")
    assert_equal(redeem[ConstructionMonad,False](False,False),"929:32")
    assert_equal(redeem[ConstructionMonad,True](False,False),"929:32")
    assert_equal(redeem[Family[False,True],False](False,False),"0:h3324")
    assert_equal(redeem[Family[False,True],True](False,False),"733:23")
    assert_equal(redeem[ResultFamily[String],False](False,True),"83:h332")
    assert_equal(redeem[ResultFamily[String],True](False,True),"83:h332")
    assert_equal(redeem[ConstructionMonad,False](False,True),"929:32")
    assert_equal(redeem[ConstructionMonad,True](False,True),"929:32")
    assert_equal(redeem[Family[False,True],False](False,True),"83:h332")
    assert_equal(redeem[Family[False,True],True](False,True),"733:23")
    assert_equal(tap[ResultFamily[String]](False,0),"0:o2")
    assert_equal(tap[ConstructionMonad](False,0),"929:2")
    assert_equal(tap[Family[False,True]](False,0),"733:2")
    assert_equal(tap[Family[True]](False,0),"731:o2")
    assert_equal(tap[ResultFamily[String]](False,1),"0:o2")
    assert_equal(tap[ConstructionMonad](False,1),"929:2")
    assert_equal(tap[Family[False,True]](False,1),"733:2")
    assert_equal(tap[Family[True]](False,1),"0:o2")
    assert_equal(tap[ResultFamily[String]](False,2),"84:o2")
    assert_equal(tap[ConstructionMonad](False,2),"929:2")
    assert_equal(tap[Family[False,True]](False,2),"733:2")
    assert_equal(tap[Family[True]](False,2),"84:o2")
    assert_equal(redeem[ResultFamily[String],False](True,False),"0:1h2234")
    assert_equal(redeem[ResultFamily[String],True](True,False),"0:1h2234")
    assert_equal(redeem[ConstructionMonad,False](True,False),"929:132")
    assert_equal(redeem[ConstructionMonad,True](True,False),"929:132")
    assert_equal(redeem[Family[False,True],False](True,False),"0:1h2234")
    assert_equal(redeem[Family[False,True],True](True,False),"733:123")
    assert_equal(redeem[ResultFamily[String],False](True,True),"83:1h223")
    assert_equal(redeem[ResultFamily[String],True](True,True),"83:1h223")
    assert_equal(redeem[ConstructionMonad,False](True,True),"929:132")
    assert_equal(redeem[ConstructionMonad,True](True,True),"929:132")
    assert_equal(redeem[Family[False,True],False](True,True),"83:1h223")
    assert_equal(redeem[Family[False,True],True](True,True),"733:123")
    assert_equal(tap[ResultFamily[String]](True,0),"0:o21")
    assert_equal(tap[ConstructionMonad](True,0),"929:12")
    assert_equal(tap[Family[False,True]](True,0),"733:12")
    assert_equal(tap[Family[True]](True,0),"0:o21")
    assert_equal(tap[ResultFamily[String]](True,1),"0:o21")
    assert_equal(tap[ConstructionMonad](True,1),"929:12")
    assert_equal(tap[Family[False,True]](True,1),"733:12")
    assert_equal(tap[Family[True]](True,1),"0:o21")
    assert_equal(tap[ResultFamily[String]](True,2),"84:o21")
    assert_equal(tap[ConstructionMonad](True,2),"929:12")
    assert_equal(tap[Family[False,True]](True,2),"733:12")
    assert_equal(tap[Family[True]](True,2),"84:o21")
