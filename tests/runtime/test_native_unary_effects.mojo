"""Thin-pointer effects survive adaptation and symbolic generic forwarding."""
from fp.callables import as_unary, NativeUnary
from std.testing import assert_equal

@fieldwise_init
struct Fault(Movable):
    var code: Int

def scalar(var value: Int) raises Never -> Int:
    return value + 1

def label(var value: Int) raises Never -> String:
    return String(value)

def size(var value: String) raises Never -> Int:
    return value.byte_length()

def suffix(var value: String) raises Never -> String:
    return value + "!"

def checked_scalar(var value: Int) raises Fault -> Int:
    if value == 0: raise Fault(1)
    return scalar(value)

def checked_label(var value: Int) raises Fault -> String:
    if value == 0: raise Fault(2)
    return label(value)

def checked_size(var value: String) raises Fault -> Int:
    if value.byte_length() == 0: raise Fault(3)
    return size(value^)

def checked_suffix(var value: String) raises Fault -> String:
    if value.byte_length() == 0: raise Fault(4)
    return suffix(value^)

def generic[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A) raises E thin -> R, var value: A
) raises E -> R:
    var callback = as_unary(function)
    return callback(value^)

def main() raises:
    var nr: def(var Int) raises Never thin -> Int = scalar
    var nm: def(var Int) raises Never thin -> String = label
    var ns: def(var String) raises Never thin -> Int = size
    var nt: def(var String) raises Never thin -> String = suffix
    var never = as_unary(nr)
    comptime assert type_of(never) == NativeUnary[Int, Int, Never, type_of(nr), True]
    assert_equal(never(1), 2)
    assert_equal(as_unary(nm)(2), "2")
    assert_equal(as_unary(ns)(String("abc")), 3)
    assert_equal(as_unary(nt)(String("a")), "a!")
    assert_equal(generic(scalar, 1), 2)
    assert_equal(generic(label, 2), "2")
    assert_equal(generic(size, String("abc")), 3)
    assert_equal(generic(suffix, String("a")), "a!")

    var rr: def(var Int) raises Fault thin -> Int = checked_scalar
    var rm: def(var Int) raises Fault thin -> String = checked_label
    var mr: def(var String) raises Fault thin -> Int = checked_size
    var mm: def(var String) raises Fault thin -> String = checked_suffix
    var first = as_unary(rr)
    var second = as_unary(rm)
    var third = as_unary(mr)
    var fourth = as_unary(mm)
    comptime assert type_of(first) == NativeUnary[Int, Int, Fault, type_of(rr), True]
    comptime assert type_of(second) == NativeUnary[Int, String, Fault, type_of(rm), True]
    comptime assert type_of(third) == NativeUnary[String, Int, Fault, type_of(mr), True]
    comptime assert type_of(fourth) == NativeUnary[String, String, Fault, type_of(mm), True]
    var a: Int
    var b: String
    var c: Int
    var d: String
    try:
        a = first.copy()(1)
        b = second.copy()(2)
        c = third.copy()(String("abc"))
        d = fourth.copy()(String("a"))
    except error:
        raise Error("unexpected pointer error")
    assert_equal(a, 2)
    assert_equal(b, "2")
    assert_equal(c, 3)
    assert_equal(d, "a!")
    try:
        a = generic(checked_scalar, 1)
        b = generic(checked_label, 2)
        c = generic(checked_size, String("abc"))
        d = generic(checked_suffix, String("a"))
    except error:
        raise Error("unexpected forwarded error")
    assert_equal(a, 2)
    assert_equal(b, "2")
    assert_equal(c, 3)
    assert_equal(d, "a!")

    var caught = 0
    try: _ = first(0)
    except error:
        comptime assert type_of(error) == Fault
        caught += error.code
    try: _ = second(0)
    except error: caught += error.code
    try: _ = third(String(""))
    except error: caught += error.code
    try: _ = as_unary[E=Fault](mm)(String(""))
    except error: caught += error.code
    assert_equal(caught, 10)
