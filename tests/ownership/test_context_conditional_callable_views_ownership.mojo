"""Conditional views preserve owned errors, captures and deferred lifetimes."""
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ResultFamily
from fp.callables import Unary, BorrowOnceCallable
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


def selected(reason: Token) -> Bool: return reason.id % 2 == 0


@fieldwise_init
struct Restore(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Token
    def call(self, var reason: Token) -> Token:
        self.capture.trace[].calls += 1
        return reason^


@fieldwise_init
struct Select(BorrowOnceCallable):
    var capture: Token
    comptime Payload = Token
    comptime Result = Bool
    def invoke_once(deinit self, ref reason: Token) -> Bool:
        self.capture.trace[].calls += 1
        return selected(reason)


@fieldwise_init
struct Retry(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Result[Token, Token]
    def call(self, var reason: Token) -> Self.Out:
        self.capture.trace[].calls += 1
        return Ok(reason^)


def check_immediate() raises:
    var captures = trace()
    var values = trace()
    var handler = kleisli[IdentityFamily](Restore(Token(7, captures)))
    var kept = Result[Token, Token](Err(Token(1, values))).recover_if(Select(Token(5, captures)), handler)
    assert_equal(kept._err().value.id, 1)
    assert_equal(values[].drops[1], 0)
    assert_equal(captures[].calls, 1)
    assert_equal(captures[].drops[5], 1)
    _ = kept^
    assert_equal(values[].drops[1], 1)
    var recovered = pipeline(Result[Token, Token](Err(Token(2, values)))).recover_if(selected, handler).get()
    assert_equal(recovered._ok().value.id, 2)
    assert_equal(captures[].calls, 2)
    _ = recovered^
    assert_equal(values[].drops[2], 1)
    var skipped = Result[Token, Token](Ok(Token(3, values))).recover_if(Select(Token(4, captures)), handler^)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[4], 1)
    assert_equal(captures[].drops[7], 1)
    _ = skipped^
    assert_equal(values[].drops[3], 1)
    var retry = kleisli[ResultFamily[Token]](Retry(Token(6, captures)))
    var replaced = pipeline(Result[Token, Token](Err(Token(4, values)))).or_else_if(selected, retry).get()
    assert_equal(replaced._ok().value.id, 4)
    _ = replaced^
    assert_equal(values[].drops[4], 1)
    assert_equal(captures[].calls, 3)
    assert_equal(captures[].drops[6], 0)
    _ = retry^
    assert_equal(captures[].drops[6], 1)


def check_deferred() raises:
    var captures = trace()
    var values = trace()
    var handler = kleisli[IdentityFamily](Restore(Token(7, captures)))
    comptime Later = ResultT[Reader[Int], Token]
    var pending = pipeline[Later](Later.fail[Token](Token(2, values))).recover_if(Select(Token(5, captures)), handler).get()
    assert_equal(captures[].calls, 0)
    assert_equal(captures[].drops[5], 0)
    var result = run[Reader[Int]](pending^, 0)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[5], 1)
    assert_equal(result._ok().value.id, 2)
    _ = result^
    assert_equal(values[].drops[2], 1)
    var abandoned = pipeline[Later](Later.fail[Token](Token(4, values))).recover_if(Select(Token(6, captures)), handler).get()
    _ = abandoned^
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[6], 1)
    assert_equal(values[].drops[4], 1)
    assert_equal(captures[].drops[7], 0)
    var moved = pipeline[Later](Later.fail[Token](Token(1, values))).recover_if(selected, handler^).get()
    var retained = run[Reader[Int]](moved^, 0)
    assert_equal(retained._err().value.id, 1)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[7], 1)
    _ = retained^
    assert_equal(values[].drops[1], 1)


def main() raises:
    check_immediate()
    check_deferred()
