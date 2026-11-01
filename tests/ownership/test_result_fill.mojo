"""Direct fill and void keep external origins and release owned payloads once."""
from fp.data import Result, Ok, Err
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


def discarded(ok: Bool) raises:
    var state = trace()
    var source = Result[Token, Token](Ok(Token(1, state))) if ok else Result[Token, Token](Err(Token(2, state)))
    var output = source^.void()
    comptime assert type_of(output) == Result[NoneType, Token]
    assert_equal(output.is_ok(), ok)
    assert_equal(state[].drops[1], Int(ok))
    assert_equal(state[].drops[2], 0)
    _ = output^
    assert_equal(state[].drops[2], Int(not ok))


def views(values: List[Int], errors: List[Int], ok: Bool) -> Result[Span[Int, origin_of(values)], Span[Int, origin_of(errors)]]:
    comptime E = Span[Int, origin_of(errors)]
    var source = Result[Int, E](Ok(1)) if ok else Result[Int, E](Err(Span(errors)))
    return source^.fill(Span(values))


def discarded_view(errors: List[Int]) -> Result[NoneType, Span[Int, origin_of(errors)]]:
    return Result[Int, Span[Int, origin_of(errors)]](Err(Span(errors))).void()


def main() raises:
    var values: List[Int] = [7]
    var errors: List[Int] = [11]
    for ok in [False, True]:
        discarded(ok)
        var output = views(values, errors, ok)
        assert_equal(output.is_ok(), ok)
        if ok:
            var view = output^.get_or(Span(values))
            assert_equal(Pointer(to=view[0]) == Pointer(to=values[0]), True)
        else:
            var view = output^.swap().get_or(Span(errors))
            assert_equal(Pointer(to=view[0]) == Pointer(to=errors[0]), True)
    var error = discarded_view(errors).swap().get_or(Span(errors))
    assert_equal(Pointer(to=error[0]) == Pointer(to=errors[0]), True)
