"""Capturing shared and mutable thunks moves each result, error and state once."""
from fp.callables import Thunk, MutableThunk, mut_ref
from fp.data import Capture, Result
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


@fieldwise_init
struct Shared(Thunk):
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    var fail: Bool
    def call(self) raises Token -> Token:
        self.capture.trace[].calls += 1
        if self.fail: raise Token(7, self.capture.trace)
        return Token(1, self.capture.trace)


@fieldwise_init
struct Mutable(MutableThunk):
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    var fail: Bool
    var calls: Int
    def call_mut(mut self) raises Token -> Token:
        self.calls += 1
        self.capture.trace[].calls += 1
        if self.fail: raise Token(7, self.capture.trace)
        return Token(1, self.capture.trace)


def owned[mutable: Bool](fail: Bool) raises:
    var state = trace()
    var outcome: Result[Token, Token]
    comptime if mutable:
        outcome = Capture[String]().run(Mutable(Token(6, state), fail, 0))
    else:
        outcome = Capture().run(Shared(Token(6, state), fail))
    assert_equal(outcome.is_err(), fail)
    assert_equal(state[].calls, 1)
    assert_equal(state[].drops[6], 1)
    assert_equal(state[].drops[1], 0)
    assert_equal(state[].drops[7], 0)
    _ = outcome^
    assert_equal(state[].drops[1], Int(not fail))
    assert_equal(state[].drops[7], Int(fail))


def retained() raises:
    var state = trace()
    var callback = Mutable(Token(6, state), True, 0)
    var failure = Capture().run(mut_ref(callback))
    assert_equal(failure.is_err(), True)
    assert_equal(callback.calls, 1)
    assert_equal(state[].drops[6], 0)
    _ = failure^
    assert_equal(state[].drops[7], 1)
    callback.fail = False
    var success = Capture[String]().run(mut_ref(callback))
    assert_equal(success.is_ok(), True)
    assert_equal(callback.calls, 2)
    assert_equal(state[].drops[6], 0)
    _ = success^
    assert_equal(state[].drops[1], 1)
    assert_equal(callback.calls, 2)
    _ = callback^
    assert_equal(state[].drops[6], 1)


@fieldwise_init
struct External[o: ImmOrigin](MutableThunk):
    comptime Out = Span[Int, Self.o]
    comptime Error = Span[Int, Self.o]
    var values: Self.Out
    var fail: Bool
    var calls: Int
    def call_mut(mut self) raises Self.Error -> Self.Out:
        self.calls += 1
        if self.fail: raise self.values
        return self.values


def external(owner: List[Int], fail: Bool) -> Result[Span[Int, origin_of(owner)], Span[Int, origin_of(owner)]]:
    var callback = External(Span(owner), fail, 0)
    return Capture().run(mut_ref(callback))


def main() raises:
    owned[False](False)
    owned[False](True)
    owned[True](False)
    owned[True](True)
    retained()
    var owner: List[Int] = [7, 11]
    var success = external(owner, False)
    assert_equal(success.is_ok(), True)
    var first = success^.get_or(Span(owner))
    assert_equal(Pointer(to=first[0]) == Pointer(to=owner[0]), True)
    var failure = external(owner, True)
    assert_equal(failure.is_err(), True)
    var second = failure^.swap().get_or(Span(owner))
    assert_equal(Pointer(to=second[0]) == Pointer(to=owner[0]), True)
