"""Borrowed payloads stay live through the handler and are then destroyed."""
from fp.data import ok, err
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Inspect(BorrowOnceCallable):
    comptime Payload = Token
    comptime Result = Token
    comptime Failure = Never
    var capture: Token
    def invoke_once(deinit self, ref value: Token) capturing -> Token:
        value.trace[].calls += 1
        value.trace[].factories += value.trace[].drops[value.id]
        return self.capture^


@fieldwise_init
struct Fail(BorrowOnceCallable):
    comptime Payload = Token
    comptime Result = Token
    comptime Failure = Token
    var capture: Token
    def invoke_once(deinit self, ref value: Token) raises Token capturing -> Token:
        value.trace[].calls += 1
        value.trace[].factories += value.trace[].drops[value.id]
        raise self.capture^


def inspect(value: Token) -> Int: return value.id


@fieldwise_init
struct Count(BorrowOnceCallable):
    comptime Payload = Token
    comptime Result = Int
    comptime Failure = Never
    var capture: Token
    def invoke_once(deinit self, ref value: Token) capturing -> Int:
        value.trace[].calls += 1
        return value.id


def owners() raises:
    var ledger = trace()
    var output = pipeline(ok[Token](Token(1, ledger))).fold(Inspect(Token(2, ledger)), Inspect(Token(3, ledger)))
    assert_equal(output.id, 2)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].factories, 0)
    assert_equal(ledger[].drops[1], 1)
    assert_equal(ledger[].drops[2], 0)
    assert_equal(ledger[].drops[3], 1)
    _ = output^
    assert_equal(ledger[].drops[2], 1)


def errors() raises:
    var ledger = trace()
    var caught = False
    try:
        _ = pipeline(err[Token](Token(1, ledger))).fold(Inspect(Token(2, ledger)), Fail(Token(3, ledger)))
    except error:
        comptime assert type_of(error) == Token
        assert_equal(error.id, 3)
        assert_equal(ledger[].drops[1], 1)
        assert_equal(ledger[].drops[2], 1)
        assert_equal(ledger[].drops[3], 0)
        _ = error^
        caught = True
    assert_equal(caught, True)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].factories, 0)
    assert_equal(ledger[].drops[3], 1)


def main() raises:
    owners()
    errors()
    var ledger = trace()
    assert_equal(pipeline(ok[Token](Token(1, ledger))).fold(inspect, inspect), 1)
    assert_equal(ledger[].drops[1], 1)
    assert_equal(pipeline(ok[Token](Token(2, ledger))).fold(Count(Token(3, ledger)), inspect), 2)
    assert_equal(pipeline(err[Token](Token(4, ledger))).fold(inspect, Count(Token(5, ledger))), 4)
    assert_equal(ledger[].calls, 2)
    for i in range(2, 6): assert_equal(ledger[].drops[i], 1)
    var owner: List[Int] = [7, 11]
    var view = Span(owner)
    comptime View = type_of(view)
    def preserve(value: View) -> View: return value
    var selected = pipeline(ok[View](view)).fold(preserve, preserve)
    selected[0] = 13
    assert_equal(owner[0], 13)
    var error_view = pipeline(err[View](view)).fold(preserve, preserve)
    assert_true(Pointer(to=error_view[1]) == Pointer(to=owner[1]))
