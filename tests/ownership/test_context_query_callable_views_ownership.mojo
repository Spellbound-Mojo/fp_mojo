"""Search and folds consume inputs while borrowing reusable capture owners."""
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid
from fp.callables import Unary
from fp.data import Result, Ok, Err
from fp.effects import Reader, run
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Select(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Optional[Token]
    def call(self, var arg: Token) -> Self.Out:
        if arg.id == self.capture.id: return Optional(arg^)
        return Optional[Token]()


@fieldwise_init
struct Project(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Result[Optional[Token], String]
    def call(self, var arg: Token) -> Self.Out:
        if arg.id == 4: return Err(String("rejected"))
        if arg.id == self.capture.id: return Ok(Optional(arg^))
        return Ok(Optional[Token]())


@fieldwise_init
struct Text(Unary):
    var capture: Token
    comptime Arg = Token
    comptime Out = Result[String, String]
    def call(self, var arg: Token) -> Self.Out:
        self.capture.trace[].calls += 1
        if arg.id == 4: return Err(String("rejected"))
        return Ok(String(arg.id))


def check_search() raises:
    var captures = trace()
    var values = trace()
    var selector = kleisli[OptionalFamily](Select(Token(2, captures)))
    var source: List[Token] = [Token(1, values), Token(2, values), Token(3, values)]
    var found = pipeline(source^).find_map(selector).get()
    assert_equal(found.value().id, 2)
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 0)
    assert_equal(values[].drops[3], 1)
    _ = found^
    assert_equal(values[].drops[2], 1)
    assert_equal(captures[].drops[2], 0)
    _ = selector^
    assert_equal(captures[].drops[2], 1)
    var projection = kleisli[ResultFamily[String]](Project(Token(2, captures)))
    var inputs: List[Token] = [Token(1, values), Token(2, values), Token(3, values)]
    var result = pipeline(inputs^).find_map_effect(projection).get()
    assert_equal(result._ok().value.value().id, 2)
    assert_equal(values[].drops[1], 2)
    assert_equal(values[].drops[2], 1)
    assert_equal(values[].drops[3], 2)
    _ = result^
    assert_equal(values[].drops[2], 2)
    var failing: List[Token] = [Token(4, values), Token(5, values)]
    assert_true(pipeline(failing^).find_map_effect(projection).get().is_err())
    assert_equal(values[].drops[4], 1)
    assert_equal(values[].drops[5], 1)
    assert_equal(captures[].drops[2], 1)
    _ = projection^
    assert_equal(captures[].drops[2], 2)


def check_fold() raises:
    var captures = trace()
    var values = trace()
    var chain = kleisli[ResultFamily[String]](Text(Token(7, captures)))
    var source: List[Token] = [Token(1, values), Token(2, values)]
    assert_equal(pipeline(source^).fold_map_effect[StringMonoid](chain).raise_on_err(), "12")
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 1)
    assert_equal(captures[].calls, 2)
    var bad: List[Token] = [Token(3, values), Token(4, values), Token(5, values)]
    assert_true(pipeline(bad^).fold_map_effect[StringMonoid](chain).get().is_err())
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
    comptime Out = Reader[Int].Pure[String]
    def call(self, var arg: Token) -> Self.Out:
        self.capture.trace[].calls += 1
        return Reader[Int].pure(String(arg.id))


def check_deferred() raises:
    var captures = trace()
    var values = trace()
    var chain = kleisli[Reader[Int]](Later(Token(7, captures)))
    var source: List[Token] = [Token(1, values), Token(2, values)]
    var pending = pipeline(source^).fold_map_effect[StringMonoid](chain).get()
    assert_equal(captures[].calls, 0)
    assert_equal(values[].drops[1], 0)
    assert_equal(run[Reader[Int]](pending^, 0), "12")
    assert_equal(captures[].calls, 2)
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 1)
    var unread: List[Token] = [Token(3, values), Token(4, values)]
    var abandoned = pipeline(unread^).fold_map_effect[StringMonoid](chain).get()
    _ = abandoned^
    assert_equal(captures[].calls, 2)
    assert_equal(values[].drops[3], 1)
    assert_equal(values[].drops[4], 1)
    assert_equal(captures[].drops[7], 0)
    _ = chain^
    assert_equal(captures[].drops[7], 1)


def main() raises:
    check_search()
    check_fold()
    check_deferred()
