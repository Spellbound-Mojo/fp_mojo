"""Generic structural contracts preserve moves, stored errors and external views."""
from fp.algebra import ResultFamily
from fp.data import Result, Ok, Err
from algebra_support.fill_contracts import filled, discarded, Failing
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


def move_values(ok: Bool) raises:
    var state = trace()
    var source = Result[Token, Token](Ok(Token(1, state))) if ok else Result[Token, Token](Err(Token(2, state)))
    var output = filled[ResultFamily[Token]](source^, Token(3, state))
    assert_equal(output.is_ok(), ok)
    assert_equal(state[].drops[1], Int(ok))
    assert_equal(state[].drops[2], 0)
    assert_equal(state[].drops[3], Int(not ok))
    var empty = discarded[ResultFamily[Token]](output^)
    assert_equal(empty.is_ok(), ok)
    assert_equal(state[].drops[3], 1)
    assert_equal(state[].drops[2], 0)
    _ = empty^
    assert_equal(state[].drops[2], Int(not ok))


def raised() raises:
    var state = trace()
    var id = 0
    try:
        _ = filled[Failing](Token(1, state), Token(3, state))
    except error:
        comptime assert type_of(error) == Token
        id = error.id
        _ = error^
    assert_equal(id, 1)
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[3], 1)


def external(values: List[Int], errors: List[Int], ok: Bool) -> Result[Span[Int, origin_of(values)], Span[Int, origin_of(errors)]]:
    comptime E = Span[Int, origin_of(errors)]
    var source = Result[Int, E](Ok(1)) if ok else Result[Int, E](Err(Span(errors)))
    return filled[ResultFamily[E]](source^, Span(values))


def main() raises:
    raised()
    var values: List[Int] = [7]
    var errors: List[Int] = [11]
    for ok in [False, True]:
        move_values(ok)
        var output = external(values, errors, ok)
        assert_equal(output.is_ok(), ok)
        if ok:
            var view = output^.get_or(Span(values))
            assert_equal(Pointer(to=view[0]) == Pointer(to=values[0]), True)
        else:
            var view = output^.swap().get_or(Span(errors))
            assert_equal(Pointer(to=view[0]) == Pointer(to=errors[0]), True)
