from fp.functions import identity, pipe
from std.testing import assert_equal


@fieldwise_init
struct Token(Movable):
    var value: Int


def make_token(x: Int) -> Token:
    return Token(x)


def consume_token(var x: Token) -> String:
    return String(x.value)


def size(x: String) -> Int:
    return x.byte_length()


def main() raises:
    var token = identity(Token(17))
    assert_equal(token.value, 17)
    assert_equal(pipe(pipe(pipe(123, make_token), consume_token), size), 3)
    assert_equal(pipe(42), 42)
    var offset = 8
    var calls = 0
    def add(x: Int) {var offset} -> Int:
        return x + offset
    assert_equal(pipe(pipe(pipe(pipe(1, add), add), add), add), 33)
    def count(x: Int) {mut calls} -> Int:
        calls += 1
        return x + calls
    assert_equal(pipe(1, count), 2)
    assert_equal(pipe(1, count), 3)
    assert_equal(calls, 2)
