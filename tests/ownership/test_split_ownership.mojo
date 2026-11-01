"""Pair transforms preserve owned captures, ordered cleanup and both origins."""
from fp.functions import split
from fp.callables import Unary, OnceUnary
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from test_pair_projections_ownership import Keep, Retry, discard, identity
from std.iter import next
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Ordered(OnceUnary):
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    var fails: Bool
    def call_once(deinit self, var value: Token) raises Token -> Token:
        self.capture.trace[].calls = self.capture.trace[].calls * 10 + self.capture.id
        if self.fails: raise value^
        return value^

def shared() raises:
    var captures = trace()
    var payloads = trace()
    var callback = split(Keep(Token(5, captures)), Keep(Token(6, captures)))
    comptime assert not conforms_to(type_of(callback), Copyable)
    var source: List[Tuple[Token, Token]] = [
        (Token(1, payloads), Token(2, payloads)),
        (Token(3, payloads), Token(4, payloads)),
    ]
    var pending = iterated(source^).map(callback)
    assert_equal(captures[].calls, 0)
    var result = next(pending)
    assert_equal(result[0].id, 1)
    assert_equal(result[1].id, 2)
    assert_equal(captures[].calls, 2)
    _ = pending^
    for id in range(3, 5): assert_equal(payloads[].drops[id], 1)
    for id in range(5, 7): assert_equal(captures[].drops[id], 0)
    _ = callback^
    for id in range(5, 7): assert_equal(captures[].drops[id], 1)
    for id in range(1, 3): assert_equal(payloads[].drops[id], 0)
    _ = result^
    for id in range(1, 3): assert_equal(payloads[].drops[id], 1)

def failures() raises:
    for failing in range(3):
        var captures = trace()
        var payloads = trace()
        var callback = split(Ordered(Token(5, captures), failing == 1),
                             Ordered(Token(6, captures), failing == 2))
        comptime assert type_of(callback).Error == Token
        assert_equal(captures[].calls, 0)
        var observed = 0
        try:
            var result = callback^.call_once((Token(1, payloads), Token(2, payloads)))
            assert result[0].id == 1 and result[1].id == 2
        except error:
            comptime assert type_of(error) == Token
            observed = error.id
        assert_equal(observed, failing)
        assert_equal(captures[].calls, 5 if failing == 1 else 56)
        for id in range(1, 3): assert_equal(payloads[].drops[id], 1)
        for id in range(5, 7): assert_equal(captures[].drops[id], 1)
    var captures = trace()
    var payloads = trace()
    var callback = split(Retry(Token(5, captures)), Retry(Token(6, captures)))
    try: _ = callback.call_mut((Token(1, payloads), Token(2, payloads)))
    except error: assert error.id == 1
    assert_equal(captures[].calls, 1)
    var saved = Optional[Tuple[Token, Token]]()
    try: saved = Optional(callback.call_mut((Token(3, payloads), Token(4, payloads))))
    except _: pass
    assert_true(saved)
    assert_equal(captures[].calls, 3)
    for id in range(5, 7): assert_equal(captures[].drops[id], 0)
    _ = callback^
    for id in range(5, 7): assert_equal(captures[].drops[id], 1)
    _ = saved^
    for id in range(1, 5): assert_equal(payloads[].drops[id], 1)

def no_value() raises:
    var payloads = trace()
    var result = split(discard, discard)((Token(1, payloads), Token(2, payloads)))
    comptime assert type_of(result) == Tuple[type_of(None), type_of(None)]
    _ = result
    for id in range(1, 3): assert_equal(payloads[].drops[id], 1)

def external(left: List[Int], right: List[Int]) -> Tuple[Span[Int, origin_of(left)], Span[Int, origin_of(right)]]:
    var a = Span(left)
    var b = Span(right)
    comptime A = type_of(a)
    comptime B = type_of(b)
    var f: def(var A) thin -> A = identity[A]
    var g: def(var B) thin -> B = identity[B]
    return split(f, g)((a, b))

def main() raises:
    shared()
    failures()
    no_value()
    var left: List[Int] = [7, 11]
    var right: List[Int] = [13, 17]
    var result = external(left, right)
    assert_true(Pointer(to=result[0][1]) == Pointer(to=left[1]))
    assert_true(Pointer(to=result[1][1]) == Pointer(to=right[1]))
