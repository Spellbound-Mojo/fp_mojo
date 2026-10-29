"""Attached values move once, copy only for repetition and retain exact origins."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline, piped
from fp.algebra import ResultFamily
from fp.effects import Reader, run
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from algebra_support.fill_contracts import Failing
from test_owned_fill import Counted
from std.testing import assert_equal


def result_attachment[left: Bool, route: Int](ok: Bool) raises:
    var state = trace()
    var source = Result[Token, Token](Ok(Token(1, state))) if ok else Result[Token, Token](Err(Token(2, state)))
    var output: Result[Tuple[Token, Token], Token]
    comptime if route == 0:
        comptime if left:
            output = pipeline(source^).tuple_left(Token(3, state)).get()
        else:
            output = pipeline(source^).tuple_right(Token(3, state)).get()
    elif route == 1:
        comptime if left:
            output = piped(source^).tuple_left(Token(3, state)).get()
        else:
            output = piped(source^).tuple_right(Token(3, state)).get()
    else:
        comptime if left:
            output = piped(source^).tuple_left[ResultFamily[Token]](Token(3, state)).get()
        else:
            output = piped(source^).tuple_right[ResultFamily[Token]](Token(3, state)).get()
    assert_equal(output.is_ok(), ok)
    assert_equal(state[].drops[1], 0)
    assert_equal(state[].drops[2], 0)
    assert_equal(state[].drops[3], Int(not ok))
    _ = output^
    assert_equal(state[].drops[1], Int(ok))
    assert_equal(state[].drops[2], Int(not ok))
    assert_equal(state[].drops[3], 1)


def copy_policy() raises:
    var state = trace()
    var single = pipeline(Optional(1)).tuple_left(Counted(state)).get()
    assert_equal(state[].factories, 0)
    assert_equal(state[].drops[3], 0)
    _ = single^
    assert_equal(state[].drops[3], 1)
    var repeated = pipeline(List[Int]([1, 2, 3])).tuple_right(Counted(state)).get()
    assert_equal(state[].factories, 3)
    assert_equal(state[].drops[3], 2)
    _ = repeated^
    assert_equal(state[].drops[3], 5)
    var lazy = iterated(range(3)).tuple_left(Counted(state)).take(1)
    assert_equal(state[].factories, 3)
    var collected = lazy^.to_list()
    assert_equal(state[].factories, 4)
    _ = collected^
    assert_equal(state[].drops[3], 7)
    var empty = pipeline(Optional[Int]()).tuple_right(Counted(state)).get()
    assert_equal(Bool(empty), False)
    assert_equal(state[].factories, 4)
    assert_equal(state[].drops[3], 8)


def fail(var value: Token) raises Int -> Token:
    raise 19


def deferred[execute: Bool, failing: Bool]() raises:
    var state = trace()
    comptime R = Reader[Int]
    var source = pipeline[R](R.pure(Token(1, state)))
    comptime if failing:
        var pending = source^.raising[Int]().map(fail).tuple_right(Token(3, state)).get()
        assert_equal(state[].drops[1], 0)
        assert_equal(state[].drops[3], 0)
        var code = 0
        try:
            _ = run[R](pending^, 0)
        except error:
            comptime assert type_of(error) == Int
            code = error
        assert_equal(code, 19)
    else:
        var pending = source^.tuple_left(Token(3, state)).get()
        assert_equal(state[].drops[1], 0)
        assert_equal(state[].drops[3], 0)
        comptime if execute:
            var output = run[R](pending^, 0)
            assert_equal(output[0].id, 3)
            assert_equal(output[1].id, 1)
            assert_equal(state[].drops[1], 0)
            assert_equal(state[].drops[3], 0)
            _ = output^
        else:
            _ = pending^
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[3], 1)


def construction_error() raises:
    var state = trace()
    var id = 0
    try:
        _ = pipeline[Failing](Token(1, state)).tuple_right(Token(3, state)).get()
    except error:
        comptime assert type_of(error) == Token
        id = error.id
        _ = error^
    assert_equal(id, 1)
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[3], 1)


def views(left: List[Int], right: List[Int], errors: List[Int], ok: Bool) -> Result[Tuple[Span[Int, origin_of(left)], Span[Int, origin_of(right)]], Span[Int, origin_of(errors)]]:
    comptime L = Span[Int, origin_of(left)]
    comptime E = Span[Int, origin_of(errors)]
    var source = Result[L, E](Ok(Span(left))) if ok else Result[L, E](Err(Span(errors)))
    return pipeline(source^).tuple_right(Span(right)).get()


def main() raises:
    comptime for side in range(2):
        comptime left = side == 0
        comptime for route in range(3):
            for ok in [False, True]:
                result_attachment[left, route](ok)
    copy_policy()
    construction_error()
    deferred[False, False]()
    deferred[True, False]()
    deferred[True, True]()
    var left: List[Int] = [7]
    var right: List[Int] = [11]
    var errors: List[Int] = [13]
    for ok in [False, True]:
        var output = views(left, right, errors, ok)
        assert_equal(output.is_ok(), ok)
        if ok:
            var present = output^.to_optional()
            var pair = present.take()
            assert_equal(Pointer(to=pair[0][0]) == Pointer(to=left[0]), True)
            assert_equal(Pointer(to=pair[1][0]) == Pointer(to=right[0]), True)
        else:
            var error = output^.swap().get_or(Span(errors))
            assert_equal(Pointer(to=error[0]) == Pointer(to=errors[0]), True)
