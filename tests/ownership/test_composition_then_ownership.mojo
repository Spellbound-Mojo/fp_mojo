"""Appending preserves flat owned storage, mutable state and consuming captures."""
from fp.functions import flow, compose, partial, Identity
from fp.callables import Unary, OnceUnary
from algebra_support.result_ownership import Token, trace
from test_context_composition_views_ownership import Pass, Once, Count
from test_mixed_pipe_ownership import identity, failure
from test_scan_callback_views_ownership import Prefix
from std.testing import assert_equal, assert_true

def plus(var value: Int) -> Int: return value + 1

def receivers() raises:
    var captures = trace()
    var payloads = trace()
    var chain = flow(Pass(Token(5, captures)), Pass(Token(6, captures))).then(Pass(Token(7, captures)))
    comptime assert type_of(chain).Fs.length == 3
    comptime assert not conforms_to(type_of(chain), Copyable)
    assert_equal(captures[].calls, 0)
    for id in range(5, 8): assert_equal(captures[].drops[id], 0)
    var value = chain(Token(1, payloads))
    assert_equal(value.id, 1)
    assert_equal(captures[].calls, 3)
    _ = value^
    assert_equal(payloads[].drops[1], 1)
    var pointer: def(var Token) thin -> Token = identity[Token]
    var extended = chain^.then(pointer)
    comptime assert type_of(extended).Fs.length == 4
    assert_equal(captures[].calls, 3)
    for id in range(5, 8): assert_equal(captures[].drops[id], 0)
    _ = extended^
    for id in range(5, 8): assert_equal(captures[].drops[id], 1)
    var count = flow(Count(0), Count(0))
    assert_equal(count.call_mut(0), 2)
    var continued = count^.then(plus)
    assert_equal(continued.call_mut(0), 5)
    var once = compose(Pass(Token(3, captures)), Once(Token(2, captures))).then(Once(Token(4, captures)))
    comptime assert conforms_to(type_of(once), OnceUnary)
    comptime assert not conforms_to(type_of(once), Unary)
    var result = once^.call_once(Token(2, payloads))
    assert_equal(result.id, 2)
    for id in range(2, 5): assert_equal(captures[].drops[id], 1)
    _ = result^
    assert_equal(payloads[].drops[2], 1)

def errors() raises:
    var captures = trace()
    var payloads = trace()
    var pointer: def(var Token) raises Token thin -> Token = failure[Token]
    var chain = flow(Pass(Token(5, captures)), pointer).then(Pass(Token(6, captures))).then(Pass(Token(7, captures)))
    assert_equal(captures[].calls, 0)
    var observed = 0
    try: _ = chain^.call_once(Token(1, payloads))
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 1)
    assert_equal(captures[].calls, 1)
    assert_equal(payloads[].drops[1], 1)
    for id in range(5, 8): assert_equal(captures[].drops[id], 1)

def copied_prefix(var prefix: Prefix, value: Int) -> Int:
    prefix.ledger[].calls += 1
    return value + 1

def prefix_copies() raises:
    var ledger = trace()
    var prefix = Prefix(ledger)
    var stage = partial(copied_prefix, prefix)
    var chain = flow(Identity[Int](), Identity[Int]()).then(stage^)
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(chain(3), 4)
    assert_equal(ledger[].factories, 2)
    assert_equal(ledger[].calls, 1)
    _ = chain^
    assert_equal(ledger[].drops[0], 2)
    _ = prefix^
    assert_equal(ledger[].drops[0], 3)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    var chain = compose(Identity[View](), Identity[View]()).then(pointer)
    return chain(view)

def main() raises:
    receivers()
    errors()
    prefix_copies()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
