"""Pair projections preserve untouched owners, cleanup on failure and output origins."""
from fp.functions import first, second
from fp.callables import Unary, MutableUnary, OnceUnary
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from std.iter import next
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Keep(Unary):
    comptime Arg = Token
    comptime Out = Token
    var capture: Token
    def call(self, var value: Token) -> Token:
        self.capture.trace[].calls += 1
        return value^

@fieldwise_init
struct Fail(OnceUnary):
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    def call_once(deinit self, var value: Token) raises Token -> Token: raise value^

@fieldwise_init
struct Retry(MutableUnary):
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    def call_mut(mut self, var value: Token) raises Token -> Token:
        self.capture.trace[].calls += 1
        if value.id == 1: raise value^
        return value^

def shared() raises:
    var captures = trace()
    var payloads = trace()
    var callback = first[Token](Keep(Token(0, captures)))
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
    assert_equal(captures[].calls, 1)
    assert_equal(payloads[].drops[1], 0)
    assert_equal(payloads[].drops[2], 0)
    _ = pending^
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)
    assert_equal(captures[].drops[0], 0)
    _ = callback^
    assert_equal(captures[].drops[0], 1)
    _ = result^
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)

def failures() raises:
    var captures = trace()
    var payloads = trace()
    var callback = second[Token](Fail(Token(0, captures)))
    var observed = 0
    try: _ = callback^.call_once((Token(2, payloads), Token(1, payloads)))
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 1)
    assert_equal(captures[].drops[0], 1)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)
    var repeated = first[Token](Retry(Token(3, captures)))
    try: _ = repeated.call_mut((Token(1, payloads), Token(2, payloads)))
    except error: observed = error.id
    assert_equal(observed, 1)
    assert_equal(captures[].calls, 1)
    assert_equal(captures[].drops[3], 0)
    var succeeded = Optional[Tuple[Token, Token]]()
    try: succeeded = Optional(repeated.call_mut((Token(3, payloads), Token(4, payloads))))
    except _: pass
    assert_true(succeeded)
    var result = succeeded.take()
    assert_equal(result[0].id, 3)
    assert_equal(result[1].id, 4)
    assert_equal(captures[].calls, 2)
    _ = repeated^
    assert_equal(captures[].drops[3], 1)
    _ = result^
    assert_equal(payloads[].drops[1], 2)
    assert_equal(payloads[].drops[2], 2)
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)

def discard(var value: Token): pass

def no_value() raises:
    var payloads = trace()
    var first_result = first[Token](discard)((Token(1, payloads), Token(2, payloads)))
    comptime assert type_of(first_result) == Tuple[type_of(None), Token]
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 0)
    assert_equal(first_result[1].id, 2)
    _ = first_result^
    assert_equal(payloads[].drops[2], 1)
    var second_result = second[Token](discard)((Token(3, payloads), Token(4, payloads)))
    comptime assert type_of(second_result) == Tuple[Token, type_of(None)]
    assert_equal(payloads[].drops[4], 1)
    assert_equal(payloads[].drops[3], 0)
    assert_equal(second_result[0].id, 3)
    _ = second_result^
    assert_equal(payloads[].drops[3], 1)


def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def increment(var value: Int) -> Int: return value + 1

def transformed(owner: List[Int]) -> Tuple[Span[Int, origin_of(owner)], Int]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    return first[Int](pointer)((view, 9))

def untouched(owner: List[Int]) -> Tuple[Span[Int, origin_of(owner)], Int]:
    var view = Span(owner)
    return second[type_of(view)](increment)((view, 9))

def main() raises:
    shared()
    failures()
    no_value()
    var owner: List[Int] = [7, 11]
    var result = transformed(owner)
    var other = untouched(owner)
    assert_true(Pointer(to=result[0][1]) == Pointer(to=owner[1]))
    assert_true(Pointer(to=other[0][1]) == Pointer(to=owner[1]))
    assert_equal(other[1], 10)
