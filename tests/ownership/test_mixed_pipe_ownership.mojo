"""Borrowed immediate stages retain captures and consume every payload once."""
from fp.functions import pipe, partial, Identity
from algebra_support.result_ownership import Token, trace
from test_context_composition_views_ownership import Pass
from test_scan_callback_views_ownership import Prefix
from std.testing import assert_equal, assert_true

def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def failure[T: Movable & Deinitable](var value: T) raises T -> T: raise value^

def shared() raises:
    var captures = trace()
    var values = trace()
    var stage = Pass(Token(6, captures))
    var pointer: def(var Token) thin -> Token = identity[Token]
    var first = pipe(Token(1, values), pointer, stage)
    var second = pipe(Token(2, values), stage, pointer)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[6], 0)
    assert_equal(first.id, 1)
    assert_equal(second.id, 2)
    assert_equal(values[].drops[1], 0)
    _ = first^
    _ = second^
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 1)
    var throwing: def(var Token) raises Token thin -> Token = failure[Token]
    var observed = 0
    try: _ = pipe(Token(3, values), throwing, stage)
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 3)
    assert_equal(captures[].calls, 2)
    try: _ = pipe(Token(4, values), stage, throwing)
    except error: observed = error.id
    assert_equal(observed, 4)
    assert_equal(captures[].calls, 3)
    assert_equal(values[].drops[3], 1)
    assert_equal(values[].drops[4], 1)
    _ = stage^
    assert_equal(captures[].drops[6], 1)

def add(var prefix: Prefix, value: Int) -> Int:
    prefix.ledger[].calls += 1
    return value + 1

def copies() raises:
    var ledger = trace()
    var prefix = Prefix(ledger)
    var stage = partial(add, prefix)
    assert_equal(ledger[].factories, 1)
    assert_equal(pipe(3, identity[Int], stage), 4)
    assert_equal(pipe(3, stage, identity[Int]), 4)
    assert_equal(ledger[].calls, 2)
    assert_equal(ledger[].factories, 3)
    _ = stage^
    assert_equal(ledger[].drops[0], 3)
    _ = prefix^
    assert_equal(ledger[].drops[0], 4)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    var stage = Identity[View]()
    return pipe(pipe(view, pointer, stage), stage, pointer)

def main() raises:
    shared()
    copies()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
