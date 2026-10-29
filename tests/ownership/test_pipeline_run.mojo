"""Pipeline execution consumes recipes and state while retaining native origins."""
from fp.functions import pipeline
from fp.effects import Reader, State, Writer, asks, modify
from fp.algebra import StringMonoid
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal

def identifier(value: Token) -> Int: return value.id

def reject(var value: Token) raises Token -> Token:
    raise Token(5, value.trace)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    return pipeline(Reader[Int].pure(Span(owner))).run(0)

def main() raises:
    var record = trace()
    var env = Token(1, record)
    var value = pipeline(asks[Reader[Token]](identifier)).run(env)
    assert_equal(value, 1)
    assert_equal(record[].drops[1], 0)
    _ = env^
    assert_equal(record[].drops[1], 1)
    var moved = pipeline(Reader[Int].pure(Token(2, record))).run(0)
    assert_equal(moved.id, 2)
    _ = moved^
    assert_equal(record[].drops[2], 1)
    var pair = pipeline(State[Token].pure(Token(3, record))).run(Token(4, record))
    assert_equal(pair[0].id, 3)
    assert_equal(pair[1].id, 4)
    assert_equal(record[].drops[3], 0)
    assert_equal(record[].drops[4], 0)
    _ = pair^
    assert_equal(record[].drops[3], 1)
    assert_equal(record[].drops[4], 1)
    var caught = 0
    try:
        _ = pipeline(modify[State[Token]](reject)).run(Token(6, record))
    except error:
        comptime assert type_of(error) == Token
        caught = error.id
        _ = error^
    assert_equal(caught, 5)
    assert_equal(record[].drops[5], 1)
    assert_equal(record[].drops[6], 1)
    var written = pipeline(Writer[StringMonoid].pure(Token(7, record))).run()
    assert_equal(written[0], "")
    assert_equal(written[1].id, 7)
    _ = written^
    assert_equal(record[].drops[7], 1)
    var owner: List[Int] = [7, 11]
    var view = external(owner)
    assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]), True)
