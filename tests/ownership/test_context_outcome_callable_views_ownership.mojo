"""Outcome views preserve original branch selection and move-only captures."""
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ResultFamily
from fp.callables import Unary
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


@fieldwise_init
struct Pass(Unary):
    var capture: Token
    var weight: Int
    comptime Arg = Token
    comptime Out = Token
    def call(self, var value: Token) -> Token:
        self.capture.trace[].calls += self.weight
        return value^


@fieldwise_init
struct Effect(Unary):
    var capture: Token
    var weight: Int
    comptime Arg = Token
    comptime Out = Result[Token, Token]
    def call(self, var value: Token) -> Self.Out:
        self.capture.trace[].calls += self.weight
        return Err(value^)


def check_borrowed() raises:
    var captures = trace()
    var values = trace()
    var on_ok = kleisli[IdentityFamily](Pass(Token(6, captures), 1))
    var on_err = kleisli[IdentityFamily](Pass(Token(7, captures), 10))
    var mapped = Result[Token, Token](Err(Token(1, values))).map_err(on_err)
    assert_equal(mapped._err().value.id, 1)
    _ = mapped^
    assert_equal(values[].drops[1], 1)
    var success = pipeline(Result[Token, Token](Ok(Token(2, values)))).map_both(on_ok, on_err).get()
    assert_equal(success._ok().value.id, 2)
    _ = success^
    assert_equal(values[].drops[2], 1)
    var recovered = Result[Token, Token](Err(Token(3, values))).redeem(on_ok, on_err)
    assert_equal(recovered._ok().value.id, 3)
    _ = recovered^
    assert_equal(values[].drops[3], 1)
    assert_equal(captures[].calls, 21)
    assert_equal(captures[].drops[6], 0)
    assert_equal(captures[].drops[7], 0)
    var owned = pipeline(Result[Token, Token](Ok(Token(4, values)))).map_both(on_ok^, on_err^).get()
    assert_equal(captures[].calls, 22)
    assert_equal(captures[].drops[6], 1)
    assert_equal(captures[].drops[7], 1)
    _ = owned^
    assert_equal(values[].drops[4], 1)


def check_effects() raises:
    var captures = trace()
    var values = trace()
    var on_ok = kleisli[ResultFamily[Token]](Effect(Token(6, captures), 1))
    var on_err = kleisli[ResultFamily[Token]](Effect(Token(7, captures), 10))
    var failed = Result[Token, Token](Ok(Token(1, values))).redeem_with(on_ok, on_err)
    assert_equal(failed._err().value.id, 1)
    assert_equal(captures[].calls, 1)
    _ = failed^
    assert_equal(values[].drops[1], 1)
    var recovered = pipeline(Result[Token, Token](Err(Token(2, values)))).redeem_with(on_ok, on_err).get()
    assert_equal(captures[].calls, 11)
    _ = recovered^
    assert_equal(values[].drops[2], 1)
    _ = on_ok^
    _ = on_err^
    assert_equal(captures[].drops[6], 1)
    assert_equal(captures[].drops[7], 1)


def check_deferred() raises:
    var captures = trace()
    var values = trace()
    var on_ok = kleisli[IdentityFamily](Pass(Token(6, captures), 1))
    var on_err = kleisli[IdentityFamily](Pass(Token(7, captures), 10))
    comptime Later = ResultT[Reader[Int], Token]
    var pending = pipeline[Later](Later.fail[Token](Token(1, values))).redeem(on_ok, on_err).get()
    assert_equal(captures[].calls, 0)
    assert_equal(values[].drops[1], 0)
    var recovered = run[Reader[Int]](pending^, 0)
    assert_equal(captures[].calls, 10)
    assert_equal(recovered._ok().value.id, 1)
    _ = recovered^
    assert_equal(values[].drops[1], 1)
    var abandoned = pipeline[Later](Later.pure(Token(2, values))).redeem(on_ok, on_err).get()
    _ = abandoned^
    assert_equal(captures[].calls, 10)
    assert_equal(values[].drops[2], 1)
    assert_equal(captures[].drops[6], 0)
    assert_equal(captures[].drops[7], 0)
    var moved = pipeline[Later](Later.fail[Token](Token(3, values))).redeem(on_ok^, on_err^).get()
    _ = moved^
    assert_equal(captures[].calls, 10)
    assert_equal(values[].drops[3], 1)
    assert_equal(captures[].drops[6], 1)
    assert_equal(captures[].drops[7], 1)


def main() raises:
    check_borrowed()
    check_effects()
    check_deferred()
