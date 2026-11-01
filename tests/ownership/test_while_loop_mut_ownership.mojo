from fp.control import while_loop_mut
from fp.callables import MutableUnary, BorrowCallable, BorrowSignature
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Carry(Movable):
    var value: Int
    var token: Token

@fieldwise_init
struct Step(MutableUnary):
    var capture: Token
    var calls: Int
    var fail: Bool
    comptime Arg = Carry
    comptime Out = Carry
    comptime Error = Token
    def call_mut(mut self, var carry: Carry) raises Token -> Carry:
        self.calls += 1
        if self.fail and carry.value == 2: raise Token(2, carry.token.trace)
        carry.value += 1
        return carry^

@fieldwise_init
struct Predicate(BorrowCallable):
    var capture: Token
    var fail: Bool
    comptime Payload = Carry
    comptime Result = Bool
    comptime Failure = Token
    def invoke(self, ref carry: Carry) raises Token -> Bool:
        self.capture.trace[].calls += 1
        if self.fail and carry.value == 2: raise Token(3, carry.token.trace)
        return carry.value < 4

@fieldwise_init
struct Tail[o: ImmOrigin](MutableUnary):
    var calls: Int
    comptime Arg = Span[Int, Self.o]
    comptime Out = Self.Arg
    def call_mut(mut self, var value: Self.Arg) -> Self.Out:
        self.calls += 1
        return value[1:]

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    comptime View = Span[Int, origin_of(owner)]
    def more(value: View) -> Bool: return len(value) > 1
    var body = Tail[origin_of(owner)](0)
    return while_loop_mut(BorrowSignature[View, Bool].capture(more), body, View(owner))

def main() raises:
    for scenario in range(3):
        var captures = trace()
        var payloads = trace()
        var body = Step(Token(5, captures), 0, scenario == 1)
        var predicate = Predicate(Token(6, captures), scenario == 2)
        comptime assert not conforms_to(type_of(body), Copyable)
        comptime assert not conforms_to(type_of(predicate), Copyable)
        var saved = Optional[Carry]()
        var observed = 0
        try: saved = Optional(while_loop_mut(predicate, body, Carry(0, Token(1, payloads))))
        except error:
            comptime assert type_of(error) == Token
            observed = error.id
        assert_equal(observed, 0 if scenario == 0 else 2 if scenario == 1 else 3)
        assert_equal(body.calls, 4 if scenario == 0 else 3 if scenario == 1 else 2)
        assert_equal(captures[].calls, 5 if scenario == 0 else 3)
        assert_equal(captures[].drops[5], 0)
        assert_equal(captures[].drops[6], 0)
        assert_equal(payloads[].drops[1], 0 if scenario == 0 else 1)
        if observed: assert_equal(payloads[].drops[observed], 1)
        if saved:
            var value = saved.take()
            assert_equal(value.value, 4)
        assert_equal(payloads[].drops[1], 1)
        var empty = Optional[Carry]()
        try: empty = Optional(while_loop_mut(predicate, body, Carry(4, Token(4, payloads))))
        except _: pass
        assert_true(empty)
        assert_equal(body.calls, 4 if scenario == 0 else 3 if scenario == 1 else 2)
        _ = body^
        _ = predicate^
        assert_equal(captures[].drops[5], 1)
        assert_equal(captures[].drops[6], 1)
        _ = empty^
        assert_equal(payloads[].drops[4], 1)
    var owner: List[Int] = [7, 11]
    var view = external(owner)
    assert_equal(len(view), 1)
    assert_true(Pointer(to=view[0]) == Pointer(to=owner[1]))
