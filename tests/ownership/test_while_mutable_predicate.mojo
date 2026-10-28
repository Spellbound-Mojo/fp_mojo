"""Owned and retained mutable loop predicates preserve state and carry ownership."""
from fp.control import while_loop_mut
from fp.callables import BorrowMutableCallable, mut_ref
from algebra_support.result_ownership import Token, trace
from test_while_loop_mut_ownership import Carry, Step, Predicate, Tail
from std.testing import assert_equal

@fieldwise_init
struct MutablePredicate(BorrowMutableCallable):
    comptime Payload = Carry
    comptime Result = Bool
    comptime Failure = Token
    var inner: Predicate
    var calls: Int
    def invoke_mut(mut self, ref carry: Carry) raises Token -> Bool:
        self.calls += 1
        return self.inner.invoke(carry)

def exercise[retained: Bool](scenario: Int) raises:
    var captures = trace()
    var payloads = trace()
    var body = Step(Token(5,captures),0,scenario == 1)
    var saved = Optional[Carry]()
    var observed = 0
    var initial = Carry(4 if scenario == 3 else 0,Token(1,payloads))
    var predicate_calls = 5 if scenario == 0 else 1 if scenario == 3 else 3
    comptime if retained:
        var predicate = MutablePredicate(Predicate(Token(6,captures),scenario == 2),0)
        try:
            saved = Optional(while_loop_mut(mut_ref(predicate),body,initial^))
        except error:
            comptime assert type_of(error) == Token
            observed = error.id
        assert_equal(predicate.calls,predicate_calls)
        assert_equal(captures[].drops[6],0)
        _ = predicate^
    else:
        try:
            saved = Optional(while_loop_mut(MutablePredicate(Predicate(Token(6,captures),scenario == 2),0),body,initial^))
        except error:
            comptime assert type_of(error) == Token
            observed = error.id
    var failed = scenario == 1 or scenario == 2
    assert_equal(observed,2 if scenario == 1 else 3 if scenario == 2 else 0)
    assert_equal(body.calls,4 if scenario == 0 else 3 if scenario == 1 else 2 if scenario == 2 else 0)
    assert_equal(captures[].calls,predicate_calls)
    assert_equal(captures[].drops[5],0)
    assert_equal(captures[].drops[6],1)
    assert_equal(payloads[].drops[1],Int(failed))
    if observed: assert_equal(payloads[].drops[observed],1)
    if saved:
        var value = saved.take()
        assert_equal(value.value,4)
    assert_equal(payloads[].drops[1],1)
    _ = body^
    assert_equal(captures[].drops[5],1)

@fieldwise_init
struct ViewPredicate[o: ImmOrigin](BorrowMutableCallable):
    comptime Payload = Span[Int,Self.o]
    comptime Result = Bool
    var calls: Int
    def invoke_mut(mut self, ref value: Self.Payload) -> Bool:
        self.calls += 1
        return len(value) > 1

def external(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    var body = Tail[origin_of(owner)](0)
    return while_loop_mut(ViewPredicate[origin_of(owner)](0),body,Span(owner))

def main() raises:
    for scenario in range(4):
        exercise[False](scenario)
        exercise[True](scenario)
    var owner: List[Int] = [7,11]
    var view = external(owner)
    assert_equal(len(view),1)
    assert_equal(Pointer(to=view[0]) == Pointer(to=owner[1]),True)
