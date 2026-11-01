"""Three-argument bundles move owners once and release only owned slots."""
from fp.data import Capture
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true


def keep(config: Token, mut state: Token, var payload: Token) -> Token:
    state.id += config.id
    return payload^


def fail(config: Token, mut state: Token, var payload: Token, /, var **extras: Token) raises Token -> Int:
    state.id += config.id
    raise payload^


def check_success() raises:
    var values = trace()
    var config = Token(0, values)
    var state = Token(1, values)
    var result = Capture[Token]().borrow(config).mutable(state).take(Token(2, values)).run(keep)
    assert_equal(result._ok().value.id, 2)
    assert_equal(values[].drops[0], 0)
    assert_equal(values[].drops[1], 0)
    assert_equal(values[].drops[2], 0)
    _ = result^
    assert_equal(values[].drops[2], 1)
    _ = config^
    _ = state^
    assert_equal(values[].drops[0], 1)
    assert_equal(values[].drops[1], 1)


def check_failure_and_abandon() raises:
    var values = trace()
    var config = Token(0, values)
    var state = Token(1, values)
    var bundle = Capture[Token]().borrow(config).mutable(state).take(Token(2, values)).kwargs(extra=Token(3, values))
    _ = bundle^
    assert_equal(values[].drops[0], 0)
    assert_equal(values[].drops[1], 0)
    assert_equal(values[].drops[2], 1)
    assert_equal(values[].drops[3], 1)
    var failed = Capture[Token]().borrow(config).mutable(state).take(Token(4, values)).kwargs(extra=Token(5, values)).run(fail)
    comptime assert type_of(failed).E == Token
    assert_equal(failed._err().value.id, 4)
    assert_equal(values[].drops[4], 0)
    assert_equal(values[].drops[5], 1)
    _ = failed^
    assert_equal(values[].drops[4], 1)
    _ = config^
    _ = state^
    assert_equal(values[].drops[0], 1)
    assert_equal(values[].drops[1], 1)


def check_origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var state = 0
    var tag = String("view")
    def return_view(label: String, mut calls: Int, var payload: View) -> View:
        calls += 1
        return payload
    var result = Capture().borrow(tag).mutable(state).take(view).run(return_view)
    assert_true(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]))
    assert_equal(state, 1)
    def raise_view(label: String, mut calls: Int, var payload: View) raises View -> Int:
        calls += 1
        raise payload
    var failed = Capture[View]().borrow(tag).mutable(state).take(view).run(raise_view)
    assert_true(Pointer(to=failed._err().value[0]) == Pointer(to=owner[0]))
    assert_equal(state, 2)


def main() raises:
    check_success()
    check_failure_and_abandon()
    check_origins(List[Int]([7, 11]))
