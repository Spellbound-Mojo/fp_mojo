"""Shared references retain owners and move payloads, outputs and failures once."""
from fp.callables import Thunk, shared_ref, call_once, invoke_borrowed_once
from fp.data import Capture, Result, Ok, Err
from test_attempt_once_receivers import Shared as Factory
from test_result_fold_receivers import Shared as Handler
from test_binary_callback_views_ownership import KeepFirst
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


def factory_calls() raises:
    var state = trace()
    var callback = Factory(Token(6, state), True)
    var reference = shared_ref(callback)
    var copied = reference
    var failure = Capture().run(reference)
    assert_equal(failure.is_err(), True)
    _ = failure^
    assert_equal(state[].drops[7], 1)
    callback.fail = False
    var success = Capture[String]().run(copied)
    assert_equal(success.is_ok(), True)
    _ = success^
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].calls, 2)
    _ = copied^
    _ = reference^
    assert_equal(state[].drops[6], 0)
    assert_equal(callback.fail, False)
    _ = callback^
    assert_equal(state[].drops[6], 1)


def handler_calls[borrowed: Bool](fail: Bool) raises:
    var state = trace()
    var callback = Handler(Token(6, state), fail)
    var reference = shared_ref(callback)
    var value = Token(2, state)
    var outcome: Result[Token, Token]
    comptime if borrowed:
        try:
            outcome = Ok(invoke_borrowed_once[Token](value, reference))
        except error:
            outcome = Err(error^)
        assert_equal(state[].drops[2], 0)
        _ = value^
    else:
        try:
            outcome = Ok(call_once(reference, value^))
        except error:
            outcome = Err(error^)
    assert_equal(outcome.is_err(), fail)
    assert_equal(state[].drops[2], 1)
    assert_equal(state[].calls, 1)
    _ = outcome^
    assert_equal(state[].drops[1], Int(not fail))
    assert_equal(state[].drops[7], Int(fail))
    _ = reference^
    assert_equal(state[].drops[6], 0)
    assert_equal(callback.fail, fail)
    _ = callback^
    assert_equal(state[].drops[6], 1)


def binary_calls() raises:
    var state = trace()
    var callback = KeepFirst(Token(6, state))
    var reference = shared_ref(callback)
    var output = call_once(reference, Token(1, state), Token(2, state))
    assert_equal(state[].drops[1], 0)
    assert_equal(state[].drops[2], 1)
    _ = output^
    assert_equal(state[].drops[1], 1)
    _ = reference^
    assert_equal(state[].drops[6], 0)
    assert_equal(callback.state.id, 6)
    _ = callback^
    assert_equal(state[].drops[6], 1)


@fieldwise_init
struct External[o: ImmOrigin](Thunk):
    comptime Out = Span[Int, Self.o]
    comptime Error = Span[Int, Self.o]
    var values: Self.Out
    var fail: Bool
    def call(self) raises Self.Error -> Self.Out:
        if self.fail: raise self.values
        return self.values


def external(owner: List[Int], fail: Bool) -> Result[Span[Int, origin_of(owner)], Span[Int, origin_of(owner)]]:
    var callback = External(Span(owner), fail)
    return Capture().run(shared_ref(callback))


def main() raises:
    factory_calls()
    binary_calls()
    for fail in [False, True]:
        handler_calls[False](fail)
        handler_calls[True](fail)
        var owner: List[Int] = [7]
        var outcome = external(owner, fail)
        assert_equal(outcome.is_err(), fail)
        if fail:
            var view = outcome^.swap().get_or(Span(owner))
            assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]), True)
        else:
            var view = outcome^.get_or(Span(owner))
            assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]), True)
