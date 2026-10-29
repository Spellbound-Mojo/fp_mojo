"""Inferred effect families preserve deferred moves, native errors and origins."""
from fp.effects import Reader, State, run
from fp.functions import pipeline, Identity
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


comptime R = Reader[Int]
comptime S = State[Token]


def reader_pair[execute: Bool]() raises:
    var state = trace()
    var recipe = pipeline(R.pure(Token(1, state))).tuple_right(Token(3, state)).get()
    assert_equal(state[].drops[1], 0)
    assert_equal(state[].drops[3], 0)
    comptime if execute:
        var pair = run[R](recipe^, 0)
        assert_equal(pair[0].id, 1)
        assert_equal(pair[1].id, 3)
        assert_equal(state[].drops[1], 0)
        assert_equal(state[].drops[3], 0)
        _ = pair^
    else:
        _ = recipe^
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[3], 1)


def state_pair() raises:
    var state = trace()
    var recipe = pipeline(S.pure(Token(1, state))).tuple_left(Token(3, state)).get()
    var pair = run[S](recipe^, Token(4, state))
    assert_equal(pair[0][0].id, 3)
    assert_equal(pair[0][1].id, 1)
    assert_equal(pair[1].id, 4)
    assert_equal(state[].drops[1], 0)
    assert_equal(state[].drops[3], 0)
    assert_equal(state[].drops[4], 0)
    _ = pair^
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[3], 1)
    assert_equal(state[].drops[4], 1)


def checked(var value: Token) raises Token -> R.Pure[Token]:
    value.trace[].calls += 1
    if value.id == 3:
        raise Token(5, value.trace)
    return R.pure(value^)


def deferred_traversal[execute: Bool]() raises:
    var state = trace()
    var inputs = List[Token]()
    for id in range(2, 5):
        inputs.append(Token(id, state))
    var recipe = pipeline(inputs^).raising[Token]().traverse(checked).get()
    assert_equal(state[].calls, 0)
    assert_equal(state[].drops[2], 0)
    comptime if execute:
        var id = 0
        try:
            _ = run[R](recipe^, 0)
        except error:
            comptime assert type_of(error) == Token
            id = error.id
            _ = error^
        assert_equal(id, 5)
        assert_equal(state[].calls, 2)
    else:
        _ = recipe^
        assert_equal(state[].calls, 0)
    for id in range(2, 5):
        assert_equal(state[].drops[id], 1)
    assert_equal(state[].drops[5], Int(execute))


def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    comptime V = Span[Int, origin_of(owner)]
    var recipe = pipeline(R.pure(Span(owner))).map(Identity[V]()).get()
    return run[R](recipe^, 0)


def main() raises:
    reader_pair[False]()
    reader_pair[True]()
    state_pair()
    deferred_traversal[False]()
    deferred_traversal[True]()
    var owner: List[Int] = [7, 11]
    var view = external(owner)
    assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]), True)
