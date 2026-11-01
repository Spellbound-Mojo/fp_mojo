"""Recovery borrows reusable captures and moves stored errors into fallbacks."""
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ResultFamily
from fp.callables import Unary
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


@fieldwise_init
struct Restore(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Token
    def call(self, var error: Token) -> Token:
        self.capture.trace[].calls += 1
        return error^


@fieldwise_init
struct Retry(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Result[Token, Token]
    def call(self, var error: Token) -> Self.Out:
        self.capture.trace[].calls += 1
        return Ok(error^)


def check_immediate() raises:
    var captures = trace()
    var values = trace()
    var restore = kleisli[IdentityFamily](Restore(Token(7, captures)))
    var source = Result[Token, Token](Err(Token(1, values)))
    var fallback = source^.value_or(restore)
    assert_equal(fallback.id, 1)
    assert_equal(values[].drops[1], 0)
    _ = fallback^
    assert_equal(values[].drops[1], 1)
    var recovered = pipeline(Result[Token, Token](Err(Token(2, values)))).recover(restore).get()
    assert_equal(recovered._ok().value.id, 2)
    _ = recovered^
    assert_equal(values[].drops[2], 1)
    var kept = Result[Token, Token](Ok(Token(3, values))).recover(restore)
    _ = kept^
    assert_equal(values[].drops[3], 1)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[7], 0)
    _ = restore^
    assert_equal(captures[].drops[7], 1)
    var retry = kleisli[ResultFamily[Token]](Retry(Token(6, captures)))
    var replaced = Result[Token, Token](Err(Token(4, values))).or_else(retry)
    assert_equal(replaced._ok().value.id, 4)
    _ = replaced^
    assert_equal(values[].drops[4], 1)
    var selected = pipeline(Result[Token, Token](Err(Token(5, values)))).or_else(retry).get()
    _ = selected^
    assert_equal(values[].drops[5], 1)
    assert_equal(captures[].drops[6], 0)
    _ = retry^
    assert_equal(captures[].drops[6], 1)


def check_moved_handlers() raises:
    var captures = trace()
    var values = trace()
    var handler = kleisli[IdentityFamily](Restore(Token(7, captures)))
    var kept = Result[Token, Token](Ok(Token(1, values))).value_or(handler^)
    assert_equal(captures[].calls, 0)
    assert_equal(captures[].drops[7], 1)
    _ = kept^
    assert_equal(values[].drops[1], 1)
    var retry = kleisli[ResultFamily[Token]](Retry(Token(6, captures)))
    var repaired = pipeline(Result[Token, Token](Err(Token(2, values)))).or_else(retry^).get()
    assert_equal(captures[].calls, 1)
    assert_equal(captures[].drops[6], 1)
    _ = repaired^
    assert_equal(values[].drops[2], 1)


comptime Layer = ResultT[Reader[Int], Token]


@fieldwise_init
struct RetryLater(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Layer.Pure[Token]
    def call(self, var error: Token) -> Self.Out:
        self.capture.trace[].calls += 1
        return Layer.pure(error^)


def check_deferred() raises:
    var captures = trace()
    var values = trace()
    var restore = kleisli[IdentityFamily](Restore(Token(7, captures)))
    var pending = pipeline[Layer](Layer.fail[Token](Token(1, values))).recover(restore).get()
    assert_equal(captures[].calls, 0)
    assert_equal(values[].drops[1], 0)
    var recovered = run[Reader[Int]](pending^, 0)
    assert_equal(captures[].calls, 1)
    assert_equal(recovered._ok().value.id, 1)
    _ = recovered^
    assert_equal(values[].drops[1], 1)
    var abandoned = pipeline[Layer](Layer.fail[Token](Token(2, values))).recover(restore).get()
    _ = abandoned^
    assert_equal(captures[].calls, 1)
    assert_equal(values[].drops[2], 1)
    assert_equal(captures[].drops[7], 0)
    _ = restore^
    assert_equal(captures[].drops[7], 1)
    var retry = kleisli[Layer](RetryLater(Token(6, captures)))
    var later = pipeline[Layer](Layer.fail[Token](Token(3, values))).or_else(retry).get()
    assert_equal(captures[].calls, 1)
    var retried = run[Reader[Int]](later^, 0)
    assert_equal(captures[].calls, 2)
    _ = retried^
    assert_equal(values[].drops[3], 1)
    assert_equal(captures[].drops[6], 0)
    var moved = pipeline[Layer](Layer.fail[Token](Token(4, values))).or_else(retry^).get()
    _ = moved^
    assert_equal(values[].drops[4], 1)
    assert_equal(captures[].drops[6], 1)


def main() raises:
    check_immediate()
    check_moved_handlers()
    check_deferred()
