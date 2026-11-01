"""Numeric folds and whole-value stages borrow or transfer captures explicitly."""
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily
from fp.callables import Unary
from fp.effects import Reader, run
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_false


@fieldwise_init
struct Number(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Optional[Int]
    def call(self, var arg: Token) -> Self.Out:
        self.capture.trace[].calls += 1
        if arg.id == 4: return Optional[Int]()
        return Optional(arg.id)


def check_sum() raises:
    var captures = trace()
    var values = trace()
    var chain = kleisli[OptionalFamily](Number(Token(7, captures)))
    var source: List[Token] = [Token(1, values), Token(2, values)]
    assert_equal(pipeline(source^).sum_by_effect(chain).get().value(), 3)
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 1)
    var failing: List[Token] = [Token(3, values), Token(4, values), Token(5, values)]
    assert_false(pipeline(failing^).sum_by_effect(chain).get())
    assert_equal(captures[].calls, 4)
    assert_equal(values[].drops[3], 1)
    assert_equal(values[].drops[4], 1)
    assert_equal(values[].drops[5], 1)
    assert_equal(captures[].drops[7], 0)
    _ = chain^
    assert_equal(captures[].drops[7], 1)


@fieldwise_init
struct Later(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Reader[Int].Pure[Int]
    def call(self, var arg: Token) -> Self.Out:
        self.capture.trace[].calls += 1
        return Reader[Int].pure(arg.id)


def check_deferred_sum() raises:
    var captures = trace()
    var values = trace()
    var chain = kleisli[Reader[Int]](Later(Token(7, captures)))
    var source: List[Token] = [Token(1, values), Token(2, values)]
    var pending = pipeline(source^).sum_by_effect(chain).get()
    assert_equal(captures[].calls, 0)
    assert_equal(values[].drops[1], 0)
    assert_equal(run[Reader[Int]](pending^, 0), 3)
    assert_equal(captures[].calls, 2)
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 1)
    var unread: List[Token] = [Token(3, values), Token(4, values)]
    var abandoned = pipeline(unread^).sum_by_effect(chain).get()
    _ = abandoned^
    assert_equal(captures[].calls, 2)
    assert_equal(values[].drops[3], 1)
    assert_equal(values[].drops[4], 1)
    assert_equal(captures[].drops[7], 0)
    _ = chain^
    assert_equal(captures[].drops[7], 1)


def start(value: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(value)


@fieldwise_init
struct Continue(Unary):
    var capture: Token
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Int]
    def call(self, var arg: Int) -> Self.Out:
        self.capture.trace[].calls += 1
        return Reader[Int].pure(arg + self.capture.id)


def check_stage_owners() raises:
    var captures = trace()
    var chain = kleisli[Reader[Int]](start).then(Continue(Token(7, captures)))
    var pending = pipeline(3).then(chain).get()
    assert_equal(captures[].calls, 0)
    assert_equal(run[Reader[Int]](pending^, 0), 10)
    assert_equal(captures[].calls, 1)
    var abandoned = pipeline(4).then(chain).get()
    _ = abandoned^
    assert_equal(captures[].drops[7], 0)
    assert_equal(run[Reader[Int]](chain.call(5), 0), 12)
    var moved = pipeline(6).then(chain^).get()
    assert_equal(captures[].drops[7], 0)
    assert_equal(run[Reader[Int]](moved^, 0), 13)
    assert_equal(captures[].drops[7], 1)
    var other = kleisli[Reader[Int]](start).then(Continue(Token(6, captures)))
    var owned = pipeline(1).then(other^).get()
    _ = owned^
    assert_equal(captures[].drops[6], 1)


def main() raises:
    check_sum()
    check_deferred_sum()
    check_stage_owners()
