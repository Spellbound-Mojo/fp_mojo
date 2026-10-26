"""Pointer copies do not copy payloads, erase origins, or invoke eagerly."""
from fp.callables import as_unary
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def checked(var value: Token) raises Token -> Token:
    if value.code < 0: raise value^
    return value^

def identity[V: Movable & Deinitable](var value: V) -> V:
    return value^

def failure[V: Movable & Deinitable](var value: V) raises V -> V:
    raise value^

def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    var callback = as_unary(pointer)
    var result = callback(view)
    comptime assert type_of(result) == View
    assert_equal(Pointer(to=result[0]) == Pointer(to=owner[0]), True)
    var throwing: def(var View) raises View thin -> View = failure[View]
    var failed = as_unary(throwing)
    var caught = view
    var did_raise = False
    try:
        _ = failed(view)
    except error:
        comptime assert type_of(error) == View
        caught = error
        did_raise = True
    assert_equal(did_raise, True)
    assert_equal(Pointer(to=caught[1]) == Pointer(to=owner[1]), True)

def main() raises:
    var drops = ArcPointer(0)
    var pointer: def(var Token) raises Token thin -> Token = checked
    var callback = as_unary(pointer)
    var copy = callback.copy()
    comptime assert conforms_to(type_of(callback), ImplicitlyCopyable)
    assert_equal(drops[], 0)
    var result: Token
    try: result = copy(Token(1, drops))
    except error: raise Error("unexpected token error")
    assert_equal(result.code, 1)
    assert_equal(drops[], 0)
    _ = result^
    assert_equal(drops[], 1)
    var code = 0
    try: _ = callback(Token(-2, drops))
    except error:
        comptime assert type_of(error) == Token
        code = error.code
    assert_equal(code, -2)
    assert_equal(drops[], 2)
    var original = callback^.into_function()
    try: _ = original(Token(3, drops))
    except error: raise Error("unexpected extracted error")
    assert_equal(drops[], 3)
    var owner: List[Int] = [3, 7]
    origins(owner)
