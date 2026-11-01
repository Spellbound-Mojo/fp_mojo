"""Borrowed payloads, move-only captures and native errors retain their owners."""
from fp.callables import BorrowSignature
from fp.functions import pipeline
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from std.iter import next
from std.testing import assert_equal, assert_true

def captures() raises:
    var captured = trace()
    var values = trace()
    var capture = Token(7, captured)
    def select(value: Token) {var capture^} -> Bool:
        capture.trace[].calls += 1
        return value.id % 2 == 0
    var callback = BorrowSignature[Token, Bool].capture(select^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    var source: List[Token] = [Token(1, values), Token(2, values), Token(3, values)]
    var pending = iterated(source^).filter(callback)
    assert_equal(captured[].calls, 0)
    assert_equal(captured[].drops[7], 0)
    var accepted = next(pending)
    assert_equal(accepted.id, 2)
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 0)
    assert_equal(captured[].calls, 2)
    _ = pending^
    assert_equal(values[].drops[3], 1)
    assert_equal(captured[].drops[7], 0)
    assert_true(callback.invoke(accepted))
    assert_equal(values[].drops[2], 0)
    var remaining: List[Token] = [Token(4, values), Token(5, values)]
    var output = pipeline(remaining^).filter(callback).get()
    assert_equal(output[0].id, 4)
    assert_equal(values[].drops[5], 1)
    assert_equal(captured[].calls, 5)
    assert_true(callback.function()(accepted))
    var extracted = callback^.into_function()
    assert_equal(captured[].drops[7], 0)
    assert_true(extracted(accepted))
    assert_equal(captured[].calls, 7)
    _ = extracted^
    assert_equal(captured[].drops[7], 1)
    _ = accepted^
    _ = output^
    assert_equal(values[].drops[2], 1)
    assert_equal(values[].drops[4], 1)

def errors() raises:
    var captures = trace()
    var errors = trace()
    var payloads = trace()
    var capture = Token(7, captures)
    def fail(value: Token) raises Token {var capture^, errors} -> Int:
        capture.trace[].calls += 1
        raise Token(value.id, errors)
    var callback = BorrowSignature[Token, Int, Token].capture(fail^)
    var value = Token(1, payloads)
    var observed = 0
    try: _ = callback.invoke(value)
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 1)
    assert_equal(errors[].drops[1], 1)
    assert_equal(payloads[].drops[1], 0)
    assert_equal(captures[].drops[7], 0)
    assert_equal(captures[].calls, 1)
    _ = callback^
    assert_equal(captures[].drops[7], 1)
    _ = value^
    assert_equal(payloads[].drops[1], 1)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    def project(value: Int) {view} -> View:
        _ = value
        return view
    var value = 0
    return BorrowSignature[Int, View].capture(project).invoke(value)

def main() raises:
    captures()
    errors()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
