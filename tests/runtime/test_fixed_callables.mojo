"""Fixed-arity callback protocols: receiver modes, dispatch and native defs."""
from fp.callables import (
    as_unary,
    UnaryContract, Unary, MutableUnary, OnceUnary, BinaryContract, Binary, MutableBinary, OnceBinary,
    ThunkContract, Thunk, MutableThunk, OnceThunk,
)
from fp.callables import call_once, call_repeated, RepeatableUnary, RepeatableBinary, RepeatableThunk
from std.testing import assert_equal


@fieldwise_init
struct Boom(Movable):
    var code: Int


@fieldwise_init
struct Token(Movable):
    var id: Int


# Direct implementations provide only their own receiver mode.
@fieldwise_init
struct Shift(Unary, Copyable):
    comptime Arg = Int
    comptime Out = Int
    var by: Int
    def call(self, var arg: Int) -> Int:
        return arg + self.by


@fieldwise_init
struct Tally(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var arg: Int) -> Int:
        self.calls += 1
        return arg * 10 + self.calls


@fieldwise_init
struct Spend(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    var token: Token
    def call_once(deinit self, var arg: Int) -> Int:
        return arg + self.token.id


# Both modes: a single call takes the consuming path.
@fieldwise_init
struct Either(Unary, OnceUnary):
    comptime Arg = Int
    comptime Out = String
    def call(self, var arg: Int) -> String:
        return "shared " + String(arg)
    def call_once(deinit self, var arg: Int) -> String:
        return "once " + String(arg)


@fieldwise_init
struct Pair(Binary):
    comptime First = Int
    comptime Second = String
    comptime Out = String
    def call(self, var first: Int, var second: String) -> String:
        return String(first) + second


@fieldwise_init
struct Join(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var first: Int, var second: Int) -> Int:
        self.calls += 1
        return first * second + self.calls


@fieldwise_init
struct Merge(OnceBinary):
    comptime First = Token
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var first: Token, var second: Int) -> Int:
        return first.id + second


@fieldwise_init
struct Seven(Thunk):
    comptime Out = Int
    def call(self) -> Int:
        return 7


@fieldwise_init
struct Drain(OnceThunk):
    comptime Out = Int
    var token: Token
    def call_once(deinit self) -> Int:
        return self.token.id


@fieldwise_init
struct Ticker(MutableThunk):
    comptime Out = Int
    var ticks: Int
    def call_mut(mut self) -> Int:
        self.ticks += 1
        return self.ticks


# Frame-generic callables, one per receiver mode.
def increment(var value: Int) -> Int:
    return value + 1


def checked(var value: Int) raises Boom -> Int:
    if value > 10:
        raise Boom(value)
    return value


def twice[F: UnaryContract & Movable & Deinitable](mut f: F, var first: F.Arg, var second: F.Arg
) raises F.Error -> Tuple[F.Out, F.Out] where RepeatableUnary[F]:
    var a = call_repeated(f, first^)
    var b = call_repeated(f, second^)
    return (a^, b^)


def protocols() raises:
    # A single call admits every receiver mode.
    assert_equal(call_once(Shift(1), 2), 3)
    assert_equal(call_once(Tally(0), 3), 31)
    assert_equal(call_once(Spend(Token(40)), 2), 42)
    assert_equal(call_once(Either(), 1), "once 1")
    # Repeated calls use a shared or exclusive receiver.
    var shift = Shift(10)
    var shifted = twice(shift, 1, 2)
    assert_equal(shifted[0], 11)
    assert_equal(shifted[1], 12)
    var tally = Tally(0)
    var tallied = twice(tally, 1, 2)
    assert_equal(tallied[0], 11)
    assert_equal(tallied[1], 22)
    assert_equal(tally.calls, 2)
    var either = Either()
    assert_equal(call_repeated(either, 2), "shared 2")
    assert_equal(call_once(Pair(), 4, "x"), "4x")
    var pair = Pair()
    assert_equal(call_repeated(pair, 5, "y"), "5y")
    var seven = Seven()
    assert_equal(call_repeated(seven) + call_repeated(seven), 14)
    assert_equal(call_once(Drain(Token(9))), 9)
    var join = Join(0)
    var joined = call_repeated(join, 2, 3)
    assert_equal(joined + call_repeated(join, 2, 3), 15)
    assert_equal(call_once(Join(0), 2, 3), 7)
    assert_equal(call_once(Merge(), Token(40), 2), 42)
    var ticker = Ticker(0)
    var ticked = call_repeated(ticker)
    assert_equal(ticked + call_repeated(ticker), 3)
    assert_equal(call_once(Ticker(4)), 5)
    comptime assert RepeatableBinary[Join] and not RepeatableBinary[Merge]
    comptime assert RepeatableThunk[Ticker] and not RepeatableThunk[Drain]
    comptime assert conforms_to(Shift, UnaryContract) and conforms_to(Spend, UnaryContract)
    comptime assert not conforms_to(Tally, Unary) and not conforms_to(Spend, MutableUnary)


def native() raises:
    comptime assert conforms_to(type_of(as_unary(increment)), Unary)
    assert_equal(as_unary(increment).call(1), 2)
    assert_equal(call_once(as_unary(increment), 2), 3)
    var inc = as_unary(increment)
    var incremented = twice(inc, 3, 4)
    assert_equal(incremented[1], 5)
    var result: Int
    try:
        result = call_once(as_unary(checked), 11)
    except error:
        result = -error.code
    assert_equal(result, -11)


def main() raises:
    protocols()
    native()
    print("fixed-arity callbacks: receiver modes, dispatch and native defs")
