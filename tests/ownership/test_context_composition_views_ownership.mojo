"""Views retain noncopyable composition captures through deferred execution."""
from fp.functions import pipeline, flow
from fp.callables import Unary, OnceUnary, MutableUnary
from fp.effects import Reader, run
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


@fieldwise_init
struct Pass(Unary):
    comptime Arg = Token
    comptime Out = Token
    var capture: Token
    def call(self, var value: Token) -> Token:
        self.capture.trace[].calls += 1
        return value^


@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Token
    comptime Out = Token
    var capture: Token
    def call_once(deinit self, var value: Token) -> Token:
        self.capture.trace[].calls += 1
        return value^


@fieldwise_init
struct Count(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + self.calls


def shared() raises:
    var captures = trace()
    var values = trace()
    var chain = flow(Pass(Token(6, captures)), Pass(Token(7, captures)))
    var pending = pipeline[Reader[Int]](Reader[Int].pure(Token(1, values))).map(chain).get()
    assert_equal(captures[].calls, 0)
    assert_equal(captures[].drops[6], 0)
    var result = run[Reader[Int]](pending^, 0)
    assert_equal(result.id, 1)
    _ = result^
    assert_equal(values[].drops[1], 1)
    assert_equal(captures[].calls, 2)
    var abandoned = pipeline[Reader[Int]](Reader[Int].pure(Token(2, values))).map(chain).get()
    _ = abandoned^
    assert_equal(values[].drops[2], 1)
    assert_equal(captures[].calls, 2)
    var moved = pipeline[Reader[Int]](Reader[Int].pure(Token(3, values))).map(chain^).get()
    assert_equal(captures[].drops[6], 0)
    _ = run[Reader[Int]](moved^, 0)
    assert_equal(captures[].calls, 4)
    assert_equal(captures[].drops[6], 1)
    assert_equal(captures[].drops[7], 1)
    assert_equal(values[].drops[3], 1)


def exclusive() raises:
    var captures = trace()
    var values = trace()
    var once = flow(Once(Token(6, captures)), Once(Token(7, captures)))
    var result = pipeline(Token(1, values)).then(once^).get()
    assert_equal(result.id, 1)
    _ = result^
    assert_equal(values[].drops[1], 1)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[6], 1)
    assert_equal(captures[].drops[7], 1)
    var counter = flow(Count(0), Count(0))
    assert_equal(pipeline(List[Int]([1, 1, 1])).map(counter^).get(), [3, 5, 7])


def temporary() raises:
    var captures = trace()
    var values = trace()
    var pending = pipeline[Reader[Int]](Reader[Int].pure(Token(1, values))).map(flow(Pass(Token(6, captures)), Pass(Token(7, captures)))).get()
    assert_equal(captures[].drops[6], 0)
    assert_equal(captures[].calls, 0)
    _ = run[Reader[Int]](pending^, 0)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[6], 1)
    assert_equal(captures[].drops[7], 1)
    assert_equal(values[].drops[1], 1)


def main() raises:
    shared()
    exclusive()
    temporary()
