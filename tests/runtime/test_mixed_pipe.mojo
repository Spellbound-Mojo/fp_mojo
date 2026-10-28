"""Immediate mixed pipelines borrow library stages and preserve native signatures."""
from fp.functions import pipe, partial, as_unary, flow, Identity
from std.testing import assert_equal

def twice(var value: Int) -> Int: return value * 2
def plus(bias: Int, value: Int) -> Int: return bias + value
def text(var value: Int) -> String: return String(value)
def size(var value: String) -> Int: return value.byte_length()
def suffix(var value: String) -> String: return value + "!"
def checked(var value: Int) raises Int -> Int:
    if value < 0: raise value
    return value

def never(var value: Int) raises Never -> Int: return value + 1
def discard(var value: Int): _ = value
def none(var value: Int) -> NoneType:
    _ = value
    return None
def raise_void(var value: Int) raises Int: raise value

def generic[A: Movable & Deinitable, R: Movable & Deinitable, //](function: def(var A) thin -> R, var value: A) -> R:
    return pipe(value^, function, Identity[R]())

def main() raises:
    var offset = partial(plus, 1)
    assert_equal(pipe(3, twice, offset), 7)
    assert_equal(pipe(3, offset, twice), 8)
    assert_equal(offset(3), 4)
    var chain = flow(twice, partial(plus, 1))
    assert_equal(pipe(3, twice, chain), 13)
    assert_equal(pipe(3, chain, twice), 14)
    assert_equal(chain(3), 7)
    var captured = 10
    def closure(var value: Int) {captured} -> Int: return captured + value
    var stored = as_unary(closure)
    assert_equal(pipe(3, twice, stored), 16)
    assert_equal(pipe(3, stored, twice), 26)
    var promoted = as_unary(twice)
    assert_equal(pipe(3, promoted, text), "6")
    var rr: def(var Int) thin -> Int = twice
    var rm: def(var Int) thin -> String = text
    var mr: def(var String) thin -> Int = size
    var mm: def(var String) thin -> String = suffix
    assert_equal(pipe(3, rr, offset), 7)
    assert_equal(pipe(3, offset, rr), 8)
    assert_equal(pipe(3, rm, Identity[String]()), "3")
    assert_equal(pipe(3, offset, rm), "4")
    assert_equal(pipe(String("abc"), mr, offset), 4)
    assert_equal(pipe(String("abc"), Identity[String](), mr), 3)
    assert_equal(pipe(String("a"), mm, Identity[String]()), "a!")
    assert_equal(pipe(String("a"), Identity[String](), mm), "a!")
    assert_equal(generic(twice, 3), 6)
    assert_equal(generic(text, 3), "3")
    assert_equal(generic(size, String("abc")), 3)
    assert_equal(generic(suffix, String("a")), "a!")
    var raising: def(var Int) raises Int thin -> Int = checked
    for native_first in range(2):
        var observed = 0
        try:
            if native_first: _ = pipe(-2, raising, offset)
            else: _ = pipe(-2, offset, raising)
        except error: observed = error
        assert_equal(observed, -2 if native_first else -1)
    var pure_error: def(var Int) raises Never thin -> Int = never
    assert_equal(pipe(3, pure_error, offset), 5)
    assert_equal(pipe(3, offset, pure_error), 5)
    var no_value: def(var Int) thin = discard
    pipe(3, no_value, Identity[type_of(None)]())
    pipe(3, offset, no_value)
    pipe(3, none, Identity[NoneType]())
    pipe(3, offset, none)
    var no_value_error: def(var Int) raises Int thin = raise_void
    var observed = 0
    try: pipe(3, offset, no_value_error)
    except error: observed = error
    assert_equal(observed, 4)
