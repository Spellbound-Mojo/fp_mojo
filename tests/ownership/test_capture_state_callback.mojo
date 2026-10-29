"""Stateful callback integration preserves moves, cleanup and external origins."""
from fp.data import Capture, Result
from fp.callables import mut_ref
from fp.functions import pipeline
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


def step(mut state: Token, var payload: Token) raises Token -> Token:
    state.trace[].calls += 1
    if payload.id == 3:
        raise Token(5, state.trace)
    return payload^


def inputs(state: type_of(trace())) -> List[Token]:
    var values = List[Token]()
    for id in range(2, 5):
        values.append(Token(id, state))
    return values^


def failed_traversal() raises:
    var state = trace()
    var callback = Capture[Token]().stateful(step, Token(1, state))
    var failed = pipeline(inputs(state)).traverse(mut_ref(callback)).get()
    assert_equal(state[].calls, 2)
    assert_equal(failed.is_err(), True)
    assert_equal(state[].drops[1], 0)
    for id in range(2, 5):
        assert_equal(state[].drops[id], 1)
    assert_equal(state[].drops[5], 0)
    _ = failed^
    assert_equal(state[].drops[5], 1)
    var returned = callback^.into_state()
    assert_equal(returned.id, 1)
    assert_equal(state[].drops[1], 0)
    _ = returned^
    assert_equal(state[].drops[1], 1)


def lazy[execute: Bool]() raises:
    var state = trace()
    var callback = Capture[Token]().stateful(step, Token(1, state))
    var pending = iterated(inputs(state)).map(callback^).take(1)
    assert_equal(state[].calls, 0)
    assert_equal(state[].drops[1], 0)
    comptime if execute:
        var output = pending^.to_list()
        assert_equal(state[].calls, 1)
        assert_equal(len(output), 1)
        assert_equal(output[0].is_ok(), True)
        assert_equal(state[].drops[2], 0)
        _ = output^
    else:
        _ = pending^
    assert_equal(state[].calls, Int(execute))
    for id in range(1, 5):
        assert_equal(state[].drops[id], 1)
    assert_equal(state[].drops[5], 0)


def view[T: Copyable & Deinitable](mut state: T, var fail: Bool) raises T -> T:
    if fail:
        raise state.copy()
    return state.copy()


def external(owner: List[Int]) -> List[Result[Span[Int, origin_of(owner)], Span[Int, origin_of(owner)]]]:
    comptime V = Span[Int, origin_of(owner)]
    var callback = Capture[V]().stateful(view[V], Span(owner))
    return pipeline[Bool]([False, True]).map(callback^).get()


def main() raises:
    failed_traversal()
    lazy[False]()
    lazy[True]()
    var owner: List[Int] = [7, 11]
    var outputs = external(owner)
    var success = outputs[0].copy().get_or(Span(owner))
    var failure = outputs[1].copy().swap().get_or(Span(owner))
    assert_equal(Pointer(to=success[0]) == Pointer(to=owner[0]), True)
    assert_equal(Pointer(to=failure[1]) == Pointer(to=owner[1]), True)
