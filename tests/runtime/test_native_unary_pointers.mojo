"""Stored pointers adapt without annotations or conversion to a closure."""
from fp.callables import as_unary, NativeUnary
from fp.functions import pipeline
from std.testing import assert_equal

def increment(var value: Int) -> Int:
    return value + 1

def different(var value: Int) -> Int:
    return value + 100

def label(var value: Int) -> String:
    return String(value)

def size(var value: String) -> Int:
    return value.byte_length()

def suffix(var value: String) -> String:
    return value + "!"

def generic[A: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A) thin -> R, var value: A
) -> R:
    # Neither argument nor result is known to use the register ABI here.
    var callback = as_unary(function)
    return callback(value^)

def main() raises:
    var rr: def(var Int) thin -> Int = increment
    var rm: def(var Int) thin -> String = label
    var mr: def(var String) thin -> Int = size
    var mm: def(var String) thin -> String = suffix
    var first = as_unary(rr)
    var second = as_unary(rm)
    var third = as_unary(mr)
    var fourth = as_unary(mm)
    comptime assert type_of(first) == NativeUnary[Int, Int, Never, type_of(rr), False]
    comptime assert type_of(second) == NativeUnary[Int, String, Never, type_of(rm), False]
    comptime assert type_of(third) == NativeUnary[String, Int, Never, type_of(mr), False]
    comptime assert type_of(fourth) == NativeUnary[String, String, Never, type_of(mm), False]
    comptime assert conforms_to(type_of(first), ImplicitlyCopyable)
    comptime assert conforms_to(type_of(second), ImplicitlyCopyable)
    comptime assert conforms_to(type_of(third), ImplicitlyCopyable)
    comptime assert conforms_to(type_of(fourth), ImplicitlyCopyable)
    assert_equal(first.copy()(1), 2)
    assert_equal(second.copy()(2), "2")
    assert_equal(third.copy()(String("abc")), 3)
    assert_equal(fourth.copy()(String("a")), "a!")

    # Declarations, stored pointers and library adapters are interchangeable
    # for a pipeline transformation. Adaptation does not retain the variable.
    assert_equal(pipeline(Optional(1)).map(increment).get().value(), 2)
    assert_equal(pipeline(Optional(1)).map(rr).get().value(), 2)
    assert_equal(pipeline(Optional(1)).map(first).get().value(), 2)
    rr = different
    assert_equal(first(1), 2)
    assert_equal(first.function()(1), 2)
    var extracted = first^.into_function()
    comptime assert type_of(extracted) == type_of(rr)
    assert_equal(extracted(1), 2)
    assert_equal(as_unary(rr)(1), 101)

    assert_equal(generic(increment, 1), 2)
    assert_equal(generic(label, 2), "2")
    assert_equal(generic(size, String("abc")), 3)
    assert_equal(generic(suffix, String("a")), "a!")
    assert_equal(as_unary[A=Int, R=String](rm)(4), "4")
