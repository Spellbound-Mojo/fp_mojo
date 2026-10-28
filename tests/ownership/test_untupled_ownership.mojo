"""Pair construction transfers move-only inputs and captures, preserving origins."""
from fp.functions import untupled, tupled
from fp.callables import Unary, MutableUnary, OnceUnary
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from std.iter import next
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Keep(Unary):
    comptime Arg = Tuple[Token, Token]
    comptime Out = Self.Arg
    var capture: Token
    def call(self, var pair: Self.Arg) -> Self.Out:
        self.capture.trace[].calls += 1
        return pair^

@fieldwise_init
struct Retry(MutableUnary):
    comptime Arg = Tuple[Token, Token]
    comptime Out = Self.Arg
    comptime Error = Self.Arg
    var capture: Token
    def call_mut(mut self, var pair: Self.Arg) raises Self.Error -> Self.Out:
        self.capture.trace[].calls += 1
        if pair[0].id == 1: raise pair^
        return pair^

@fieldwise_init
struct Fail(OnceUnary):
    comptime Arg = Tuple[Token, Token]
    comptime Out = Self.Arg
    comptime Error = Self.Arg
    var capture: Token
    def call_once(deinit self, var pair: Self.Arg) raises Self.Error -> Self.Out: raise pair^

def shared() raises:
    var captures = trace()
    var payloads = trace()
    var callback = untupled(Keep(Token(0, captures)))
    comptime assert not conforms_to(type_of(callback), Copyable)
    var left: List[Token] = [Token(1, payloads), Token(3, payloads)]
    var right: List[Token] = [Token(2, payloads), Token(4, payloads)]
    var pending = iterated(left^).zip_with(right^, callback)
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
    var once = untupled(Fail(Token(0, captures)))
    var observed = 0
    try: _ = once^.call_once(Token(1, payloads), Token(2, payloads))
    except error:
        comptime assert type_of(error) == Tuple[Token, Token]
        observed = error[0].id
    assert_equal(observed, 1)
    assert_equal(captures[].drops[0], 1)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)
    var repeated = untupled(Retry(Token(3, captures)))
    try: _ = repeated.call_mut(Token(1, payloads), Token(2, payloads))
    except error: observed = error[0].id
    assert_equal(observed, 1)
    assert_equal(captures[].calls, 1)
    assert_equal(captures[].drops[3], 0)
    var succeeded = Optional[Tuple[Token, Token]]()
    try: succeeded = Optional(repeated.call_mut(Token(3, payloads), Token(4, payloads)))
    except _: pass
    assert_true(succeeded)
    var result = succeeded.take()
    assert_equal(result[0].id, 3)
    assert_equal(result[1].id, 4)
    _ = result^
    _ = repeated^
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[3], 1)
    assert_equal(payloads[].drops[1], 2)
    assert_equal(payloads[].drops[2], 2)
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)

def keep[T: Movable & Deinitable](var pair: Tuple[T, T]) -> Tuple[T, T]: return pair^
def fail(var pair: Tuple[Token, Token]) raises Tuple[Token, Token] -> Int: raise pair^
def read(pair: Tuple[Token, Token]) -> Int: return pair[0].id + pair[1].id
def discard(var pair: Tuple[Token, Token]): pass

def native() raises:
    var payloads = trace()
    var pointer: def(var Tuple[Token, Token]) raises Tuple[Token, Token] thin -> Int = fail
    var observed = 0
    try: _ = untupled(pointer)(Token(1, payloads), Token(2, payloads))
    except error: observed = error[1].id
    assert_equal(observed, 2)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)
    assert_equal(untupled(read)(Token(3, payloads), Token(4, payloads)), 7)
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)
    untupled(discard)(Token(5, payloads), Token(6, payloads))
    assert_equal(payloads[].drops[5], 1)
    assert_equal(payloads[].drops[6], 1)

def external(owner: List[Int]) -> Tuple[Span[Int, origin_of(owner)], Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var Tuple[View, View]) thin -> Tuple[View, View] = keep[View]
    return untupled(pointer)(view, view)

def main() raises:
    shared()
    failures()
    native()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[0][1]) == Pointer(to=owner[1]))
    assert_true(Pointer(to=result[1][0]) == Pointer(to=owner[0]))
