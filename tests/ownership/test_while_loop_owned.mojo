"""While loops consume callback owners on false predicates and exact typed failures."""
from fp.control import while_loop
from fp.callables import MutableUnary, mut_ref
from test_while_loop_mut_ownership import Carry, Step, Predicate, Tail
from test_while_mutable_predicate import MutablePredicate, ViewPredicate
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal

@fieldwise_init
struct Recorded(MutableUnary):
    comptime Arg=Carry
    comptime Out=Carry
    comptime Error=Token
    var inner:Step
    def call_mut(mut self,var carry:Carry) raises Token -> Carry:
        return self.inner.call_mut(carry^)
    def __deinit__(deinit self):
        self.inner.capture.trace[].factories=self.inner.calls

def exercise[mode:Int](scenario:Int) raises:
    var captures=trace()
    var payloads=trace()
    var saved=Optional[Carry]()
    var observed=0
    var initial=Carry(4 if scenario==3 else 0,Token(1,payloads))
    var expected_predicate=5 if scenario==0 else 1 if scenario==3 else 3
    var expected_body=4 if scenario==0 else 3 if scenario==1 else 2 if scenario==2 else 0
    comptime if mode==0:
        try:
            saved=Optional(while_loop(MutablePredicate(Predicate(Token(6,captures),scenario==2),0),Recorded(Step(Token(5,captures),0,scenario==1)),initial^))
        except error:
            comptime assert type_of(error)==Token
            observed=error.id
    elif mode==1:
        var predicate=MutablePredicate(Predicate(Token(6,captures),scenario==2),0)
        var body=Recorded(Step(Token(5,captures),0,scenario==1))
        try:
            saved=Optional(while_loop(mut_ref(predicate),mut_ref(body),initial^))
        except error:
            comptime assert type_of(error)==Token
            observed=error.id
        assert_equal(predicate.calls,expected_predicate)
        assert_equal(body.inner.calls,expected_body)
        assert_equal(captures[].drops[5],0)
        assert_equal(captures[].drops[6],0)
        _=predicate^
        _=body^
    else:
        var predicate=Predicate(Token(6,captures),scenario==2)
        try:
            saved=Optional(while_loop(predicate,Recorded(Step(Token(5,captures),0,scenario==1)),initial^))
        except error:
            comptime assert type_of(error)==Token
            observed=error.id
        assert_equal(captures[].drops[6],0)
        _=predicate^
    var failed=scenario==1 or scenario==2
    assert_equal(observed,2 if scenario==1 else 3 if scenario==2 else 0)
    assert_equal(captures[].calls,expected_predicate)
    assert_equal(captures[].factories,expected_body)
    assert_equal(captures[].drops[5],1)
    assert_equal(captures[].drops[6],1)
    assert_equal(payloads[].drops[1],Int(failed))
    if observed: assert_equal(payloads[].drops[observed],1)
    if saved:
        var value=saved.take()
        assert_equal(value.value,4)
    assert_equal(payloads[].drops[1],1)

def external(owner:List[Int]) -> Span[Int,origin_of(owner)]:
    return while_loop(ViewPredicate[origin_of(owner)](0),Tail[origin_of(owner)](0),Span(owner))

def native_predicate(value:Carry)->Bool: return value.value<4

def main() raises:
    for scenario in range(4):
        comptime for mode in range(3): exercise[mode](scenario)
    var owner:List[Int]=[7,11]
    var view=external(owner)
    assert_equal(len(view),1)
    assert_equal(Pointer(to=view[0])==Pointer(to=owner[1]),True)
    var captures=trace()
    var payloads=trace()
    var final:Carry
    try:
        final=while_loop(native_predicate,Recorded(Step(Token(5,captures),0,False)),Carry(0,Token(1,payloads)))
    except: raise Error("unexpected native predicate failure")
    assert_equal(captures[].factories,4)
    assert_equal(captures[].drops[5],1)
    assert_equal(final.value,4)
    _=final^
    assert_equal(payloads[].drops[1],1)
