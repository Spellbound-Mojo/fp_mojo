"""Exclusive counted loops borrow move-only callbacks and consume each carry once."""
from fp.control import fori_loop_mut
from fp.callables import MutableBinary
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Carry(Movable):
    var value: Int
    var token: Token

@fieldwise_init
struct Step(MutableBinary):
    var capture: Token
    var calls: Int
    var fail_at: Int
    comptime First = Int
    comptime Second = Carry
    comptime Out = Carry
    comptime Error = Token
    def call_mut(mut self, var index: Int, var carry: Carry) raises Token -> Carry:
        self.calls += 1
        if index == self.fail_at: raise Token(2, carry.token.trace)
        carry.value += index
        return carry^

@fieldwise_init
struct Keep[o: ImmOrigin](MutableBinary):
    var calls: Int
    comptime First = Int
    comptime Second = Span[Int, Self.o]
    comptime Out = Self.Second
    def call_mut(mut self, var index: Int, var value: Self.Second) -> Self.Out:
        self.calls += 1
        return value

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var body = Keep[origin_of(owner)](0)
    return fori_loop_mut(0, 3, body, Span(owner))

def main() raises:
    for fail in [False, True]:
        var captures = trace()
        var payloads = trace()
        var body = Step(Token(5, captures), 0, 2 if fail else -1)
        comptime assert not conforms_to(type_of(body), Copyable)
        var saved = Optional[Carry]()
        var observed = 0
        try: saved = Optional(fori_loop_mut[unroll=3](0, 5, body, Carry(0, Token(1, payloads))))
        except error:
            comptime assert type_of(error) == Token
            observed = error.id
        assert_equal(observed, 2 if fail else 0)
        assert_equal(body.calls, 3 if fail else 5)
        assert_equal(captures[].drops[5], 0)
        assert_equal(payloads[].drops[1], 1 if fail else 0)
        assert_equal(payloads[].drops[2], 1 if fail else 0)
        if saved:
            var carry = saved.take()
            assert_equal(carry.value, 10)
        assert_equal(payloads[].drops[1], 1)
        var empty = Optional[Carry]()
        try: empty = Optional(fori_loop_mut[5, 2, unroll=0](body, Carry(7, Token(3, payloads))))
        except _: pass
        assert_true(empty)
        assert_equal(body.calls, 3 if fail else 5)
        _ = body^
        assert_equal(captures[].drops[5], 1)
        _ = empty^
        assert_equal(payloads[].drops[3], 1)
    var owner: List[Int] = [7, 11]
    var view = external(owner)
    assert_true(Pointer(to=view[1]) == Pointer(to=owner[1]))
