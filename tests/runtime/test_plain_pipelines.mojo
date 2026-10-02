"""Plain functions in pipe, flow and compose without promotion."""
from fp.functions import pipe, flow, compose, as_unary, partial
from fp.callables import Thunk, Unary, Binary, MutableUnary, OnceUnary
from std.testing import assert_equal, assert_true


def twice(value: Int) -> Int:
    return value * 2


def inc(var value: Int) -> Int:
    return value + 1


def label(value: Int) -> String:
    return "v=" + String(value)


def shout(var text: String) -> String:
    return text + "!"


def size(text: String) -> Int:
    return text.byte_length()


def add(a: Int, b: Int) -> Int:
    return a + b


def seven() -> Int:
    return 7


@fieldwise_init
struct Bad(Movable, Writable):
    var code: Int


def check(value: Int) raises Bad -> Int:
    if value < 0:
        raise Bad(value)
    return value


def checked_add(a: Int, b: Int) raises Bad -> Int:
    return check(a + b)


def pipelines() raises:
    assert_equal(pipe(3, twice, inc), 7)
    assert_equal(pipe(3, twice, inc, label), "v=7")
    assert_equal(pipe(3, label, shout, size), 4)
    assert_equal(pipe(0, inc, inc, inc, inc, inc, inc, inc, twice), 14)
    comptime assert type_of(pipe(3, twice, label)) == String
    var code = 0
    try:
        _ = pipe(-3, twice, check, label)
    except error:
        comptime assert type_of(error) == Bad
        code = error.code
    assert_equal(code, -6)
    # A pure pipeline does not raise.
    def pure_only() -> Int:
        return pipe(1, twice, inc)
    assert_equal(pure_only(), 3)


def compositions() raises:
    var forward = flow(twice, inc, label)
    assert_equal(forward(5), "v=11")
    comptime assert conforms_to(type_of(forward), Unary)
    comptime assert conforms_to(type_of(forward), MutableUnary) and conforms_to(type_of(forward), OnceUnary)
    comptime assert conforms_to(type_of(forward), Copyable)
    var backward = compose(label, inc, twice)
    assert_equal(backward(5), "v=11")
    var eight = flow(inc, inc, inc, inc, inc, inc, inc, twice)
    assert_equal(eight(0), 14)
    # The first-applied function fixes the arity.
    var binary = flow(add, twice)
    assert_equal(binary(2, 3), 10)
    comptime assert conforms_to(type_of(binary), Binary)
    var nullary = flow(seven, inc, label)
    assert_equal(nullary(), "v=8")
    comptime assert conforms_to(type_of(nullary), Thunk)
    var composed_binary = compose(label, twice, add)
    assert_equal(composed_binary(1, 2), "v=6")
    var composed_nullary = compose(inc, seven)
    assert_equal(composed_nullary(), 8)
    # Errors keep their type and stop the chain.
    var failing = flow(checked_add, twice)
    var code = 0
    try:
        _ = failing(-5, 1)
    except error:
        comptime assert type_of(error) == Bad
        code = error.code
    assert_equal(code, -4)
    # A composition of plain functions is a library value; beside it, native
    # functions are promoted.
    var nested = flow(forward^, as_unary(shout))
    assert_equal(nested(1), "v=3!")


def mixed() raises:
    var k = 5
    def plus(value: Int) {imm k} -> Int:
        return value + k
    # A closure needs as_unary; then every native stage is promoted.
    assert_equal(pipe(3, as_unary(twice), partial(add, 1), as_unary(plus)), 12)
    assert_equal(flow(as_unary(plus), as_unary(twice))(1), 12)
    # A plain composition is a Unary stage beside promoted ones.
    assert_equal(pipe(1, flow(twice, inc), as_unary(plus)), 8)


def main() raises:
    pipelines()
    compositions()
    mixed()
    print("plain pipelines: pipe, flow and compose over 2-8 plain functions")
