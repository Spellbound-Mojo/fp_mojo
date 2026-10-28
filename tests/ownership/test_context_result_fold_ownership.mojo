"""The selected payload moves once; both callback owners are cleaned up."""
from fp.data import Result, ok, err
from fp.functions import pipeline
from fp.callables import OnceUnary, MutableUnary
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Keep(OnceUnary):
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Never
    var capture: Token
    def call_once(deinit self, var value: Token) -> Token:
        self.capture.trace[].calls += 1
        return value^


@fieldwise_init
struct Raise(MutableUnary):
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    def call_mut(mut self, var value: Token) raises Token -> Token:
        self.capture.trace[].calls += 1
        raise value^


def success() raises:
    var ledger = trace()
    var output = pipeline(ok[Token](Token(1, ledger))).fold_owned(Keep(Token(2, ledger)), Keep(Token(3, ledger)))
    assert_equal(output.id, 1)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].drops[1], 0)
    assert_equal(ledger[].drops[2], 1)
    assert_equal(ledger[].drops[3], 1)
    _ = output^
    assert_equal(ledger[].drops[1], 1)


def failure() raises:
    var ledger = trace()
    var caught = False
    try:
        _ = pipeline(err[Token](Token(1, ledger))).fold_owned(Keep(Token(2, ledger)), Raise(Token(3, ledger)))
    except error:
        comptime assert type_of(error) == Token
        assert_equal(error.id, 1)
        assert_equal(ledger[].drops[1], 0)
        _ = error^
        caught = True
    assert_equal(caught, True)
    assert_equal(ledger[].calls, 1)
    for i in range(1, 4): assert_equal(ledger[].drops[i], 1)


def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var value: View) -> View: return value
    var result = pipeline(ok[View](view)).fold_owned(keep, keep)
    assert_true(Pointer(to=result[0]) == Pointer(to=owner[0]))
    var other = pipeline(err[View](view)).fold_owned(keep, keep)
    assert_true(Pointer(to=other[1]) == Pointer(to=owner[1]))


def mutable_origin() raises:
    var owner: List[Int] = [13, 17]
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var value: View) -> View: return value
    var result = pipeline(ok[View](view)).fold_owned(keep, keep)
    result[0] = 19
    assert_equal(owner[0], 19)
    var other = pipeline(err[View](view)).fold_owned(keep, keep)
    assert_true(Pointer(to=other[1]) == Pointer(to=owner[1]))


def main() raises:
    success()
    failure()
    var owner: List[Int] = [7, 11]
    origins(owner)
    mutable_origin()
