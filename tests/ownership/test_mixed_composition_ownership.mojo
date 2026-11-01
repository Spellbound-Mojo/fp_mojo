"""Mixed admission owns stages without copying captures or extending output origins."""
from fp.functions import flow, compose, Identity, pipeline
from fp.effects import Reader, run
from fp.callables import Unary, OnceUnary
from test_context_composition_views_ownership import Pass, Once
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true

def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def failure[T: Movable & Deinitable](var value: T) raises T -> T: raise value^

def owned() raises:
    var captures = trace()
    var values = trace()
    var pointer: def(var Token) thin -> Token = identity[Token]
    var chain = flow(pointer, Pass(Token(6, captures)))
    comptime assert not conforms_to(type_of(chain), Copyable)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(Token(1, values))).map(chain).get()
    assert_equal(captures[].calls, 0)
    assert_equal(captures[].drops[6], 0)
    var value = run[Reader[Int]](pending^, 0)
    assert_equal(value.id, 1)
    assert_equal(captures[].calls, 1)
    _ = value^
    assert_equal(values[].drops[1], 1)
    var abandoned = pipeline[Reader[Int]](Reader[Int].pure(Token(2, values))).map(chain).get()
    _ = abandoned^
    assert_equal(values[].drops[2], 1)
    assert_equal(captures[].calls, 1)
    var moved = pipeline[Reader[Int]](Reader[Int].pure(Token(3, values))).map(chain^).get()
    _ = moved^
    assert_equal(captures[].calls, 1)
    assert_equal(captures[].drops[6], 1)
    assert_equal(values[].drops[3], 1)
    var consuming = compose(pointer, Once(Token(7, captures)))
    comptime assert conforms_to(type_of(consuming), OnceUnary)
    comptime assert not conforms_to(type_of(consuming), Unary)
    var result = consuming^.call_once(Token(4, values))
    assert_equal(result.id, 4)
    assert_equal(captures[].calls, 2)
    assert_equal(captures[].drops[7], 1)
    _ = result^
    assert_equal(values[].drops[4], 1)

def errors() raises:
    var values = trace()
    var captures = trace()
    var pointer: def(var Token) raises Token thin -> Token = failure[Token]
    var first = flow(pointer, Pass(Token(6, captures)))
    var last = flow(Pass(Token(7, captures)), pointer)
    assert_equal(captures[].calls, 0)
    var observed = 0
    try: _ = first(Token(1, values))
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 1)
    assert_equal(values[].drops[1], 1)
    assert_equal(captures[].calls, 0)
    try: _ = last(Token(2, values))
    except error: observed = error.id
    assert_equal(observed, 2)
    assert_equal(values[].drops[2], 1)
    assert_equal(captures[].calls, 1)
    _ = first^
    _ = last^
    assert_equal(captures[].drops[6], 1)
    assert_equal(captures[].drops[7], 1)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    var first = flow(pointer, Identity[View]())
    var second = compose(pointer, Identity[View]())
    return second(first(view))

def origin_errors(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) raises View thin -> View = failure[View]
    var chain = flow(Identity[View](), pointer)
    var observed = False
    try: _ = chain(view)
    except error:
        comptime assert type_of(error) == View
        assert_true(Pointer(to=error[1]) == Pointer(to=owner[1]))
        observed = True
    assert_true(observed)

def main() raises:
    owned()
    errors()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[0]) == Pointer(to=owner[0]))
    origin_errors(owner)
