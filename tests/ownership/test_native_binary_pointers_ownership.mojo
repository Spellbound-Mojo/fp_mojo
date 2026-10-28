"""Binary adapters retain exact owned payloads, captures and embedded origins."""
from fp.callables import as_binary, NativeBinary
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true

def keep[T: Movable & Deinitable](var first: T, var second: T) -> T:
    _ = second^
    return first^

def fail[T: Movable & Deinitable](var first: T, var second: T) raises T -> T:
    _ = second^
    raise first^

def inspect(first: Token, second: Token) -> Int: return first.id + second.id

def payloads() raises:
    var values = trace()
    var pointer: def(var Token, var Token) thin -> Token = keep[Token]
    var callback = as_binary(pointer)
    var result = callback(Token(1, values), Token(2, values))
    assert_equal(values[].drops[1], 0)
    assert_equal(values[].drops[2], 1)
    assert_equal(result.id, 1)
    _ = result^
    assert_equal(values[].drops[1], 1)
    var raising: def(var Token, var Token) raises Token thin -> Token = fail[Token]
    var observed = 0
    try: _ = as_binary(raising)(Token(3, values), Token(4, values))
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 3)
    assert_equal(values[].drops[3], 1)
    assert_equal(values[].drops[4], 1)
    assert_equal(as_binary(inspect)(Token(5, values), Token(6, values)), 11)
    assert_equal(values[].drops[5], 1)
    assert_equal(values[].drops[6], 1)

def captures() raises:
    # The public storage type retains the existing explicitly typed closure
    # path. The inferred factory deliberately admits thin pointers only.
    var captures = trace()
    var values = trace()
    var capture = Token(7, captures)
    def native(var first: Token, var second: Token) {var capture^} -> Token:
        capture.trace[].calls += 1
        _ = second^
        return first^
    var callback = NativeBinary[Token, Token, Token, Never, type_of(native), False](native^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    assert_equal(captures[].calls, 0)
    assert_equal(captures[].drops[7], 0)
    _ = callback(Token(1, values), Token(2, values))
    _ = callback(Token(3, values), Token(4, values))
    assert_equal(captures[].calls, 2)
    for id in range(1, 5): assert_equal(values[].drops[id], 1)
    var extracted = callback^.into_function()
    assert_equal(captures[].drops[7], 0)
    _ = extracted^
    assert_equal(captures[].drops[7], 1)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View, var View) thin -> View = keep[View]
    return as_binary(pointer)(view, view)

def main() raises:
    payloads()
    captures()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
