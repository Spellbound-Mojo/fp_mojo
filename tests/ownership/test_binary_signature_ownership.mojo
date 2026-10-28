"""Typed capture retains noncopyable closure state and native origins."""
from fp.callables import BinarySignature
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true

def captures() raises:
    var captured = trace()
    var values = trace()
    var capture = Token(7, captured)
    def native(var first: Token, var second: Token) {var capture^} -> Token:
        capture.trace[].calls += 1
        _ = second^
        return first^
    var callback = BinarySignature[Token, Token, Token].capture(native^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    var left = List[Token]()
    var right = List[Token]()
    left.append(Token(1, values))
    left.append(Token(2, values))
    right.append(Token(3, values))
    right.append(Token(4, values))
    var pending = iterated(left^).zip_with(right^, callback)
    assert_equal(captured[].calls, 0)
    assert_equal(captured[].drops[7], 0)
    var output = pending^.collect_list()
    assert_equal(captured[].calls, 2)
    assert_equal(output[0].id, 1)
    assert_equal(output[1].id, 2)
    assert_equal(values[].drops[3], 1)
    assert_equal(values[].drops[4], 1)
    _ = output^
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 1)
    var extracted = callback^.into_function()
    assert_equal(captured[].drops[7], 0)
    _ = extracted^
    assert_equal(captured[].drops[7], 1)

def errors() raises:
    var captured = trace()
    var values = trace()
    var capture = Token(7, captured)
    def native(var first: Token, var second: Token) raises Token {var capture^} -> Token:
        capture.trace[].calls += 1
        _ = second^
        raise first^
    var callback = BinarySignature[Token, Token, Token, Token].capture(native^)
    var observed = 0
    try: _ = callback(Token(1, values), Token(2, values))
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 1)
    assert_equal(captured[].calls, 1)
    assert_equal(values[].drops[1], 1)
    assert_equal(values[].drops[2], 1)
    _ = callback^
    assert_equal(captured[].drops[7], 1)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    def choose(var first: View, var second: View) {ref owner} -> View:
        _ = len(owner)
        _ = second
        return first
    return BinarySignature[View, View, View].capture(choose)(view, view)

def main() raises:
    captures()
    errors()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
