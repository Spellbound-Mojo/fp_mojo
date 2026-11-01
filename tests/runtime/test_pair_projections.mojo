"""Cats-style pair projections reuse unary callbacks without changing their effects."""
from fp.functions import first, second, partial, flow, pipeline, as_unary
from fp.iteration import iterated
from fp.callables import Unary, MutableUnary, OnceUnary
from test_fixed_callables import Tally, Spend, Token
from test_repeatable_mapping import Dual
from std.testing import assert_equal

def increment(var value: Int) -> Int: return value + 1
def decrement(var value: Int) -> Int: return value - 1
def render(var value: Int) -> String: return String(value)
def decorate(var value: String) -> String: return value + "!"
def size(var value: String) -> Int: return value.byte_length()
def scaled(factor: Int, value: Int) -> Int: return factor * value
def fail(var value: Int) raises Int -> Int: raise value
def never(var value: Int) raises Never -> Int: return value + 1
def no_value(var value: Int): pass
def impossible_void(var value: Int) raises Never: pass
def fail_void(var value: Int) raises Int: raise value
def unit(var value: Int) -> NoneType:
    _ = value
    return None

def workflows() raises:
    var priced = first[String](partial(scaled, 3))
    assert_equal(priced((2, String("id"))), (6, String("id")))
    var source: List[Tuple[Int, String]] = [(1, String("a")), (2, String("b"))]
    assert_equal(pipeline(source^).map(priced).get(), [(3, String("a")), (6, String("b"))])
    var displayed = flow(priced^, first[String](render))
    assert_equal(displayed((2, String("id"))), (String("6"), String("id")))
    var counted = second[String](Tally(0))
    comptime assert conforms_to(type_of(counted), MutableUnary)
    comptime assert not conforms_to(type_of(counted), Unary)
    var values: List[Tuple[String, Int]] = [(String("a"), 1), (String("b"), 2)]
    assert_equal(iterated(values^).map(counted^).collect_list(), [(String("a"), 11), (String("b"), 22)])
    var once = first[String](Spend(Token(7)))
    comptime assert conforms_to(type_of(once), OnceUnary)
    comptime assert not conforms_to(type_of(once), MutableUnary)
    assert_equal(once^.call_once((2, String("id"))), (9, String("id")))
    var dual = second[String](Dual(0))
    assert_equal(dual((String("id"), 1)), (String("id"), 101))
    assert_equal(dual.call_mut((String("id"), 1)), (String("id"), 202))
    assert_equal(dual^.call_once((String("id"), 1)), (String("id"), 901))
    var offset = 4
    var calls = 0
    def captured(var value: Int) {offset, mut calls} -> Int:
        calls += 1
        return value + offset
    assert_equal(first[String](as_unary(captured))((2, String("id"))), (6, String("id")))
    assert_equal(calls, 1)

def native() raises:
    var rr: def(var Int) thin -> Int = increment
    var rm: def(var Int) thin -> String = render
    var mm: def(var String) thin -> String = decorate
    var mr: def(var String) thin -> Int = size
    var stored = first[String](rr)
    rr = decrement
    assert_equal(stored((2, String("id"))), (3, String("id")))
    assert_equal(second[String](rr)((String("id"), 2)), (String("id"), 1))
    assert_equal(first[String](rm)((2, String("id"))), (String("2"), String("id")))
    assert_equal(second[Int](mm)((1, String("a"))), (1, String("a!")))
    assert_equal(first[Int](mr)((String("abc"), 9)), (3, 9))
    var raising: def(var Int) raises Int thin -> Int = fail
    var projected = second[String](raising)
    comptime assert type_of(projected).Error == Int
    var observed = 0
    try: _ = projected((String("id"), 7))
    except error: observed = error
    assert_equal(observed, 7)
    var impossible: def(var Int) raises Never thin -> Int = never
    assert_equal(first[String](impossible)((2, String("id"))), (3, String("id")))
    var procedure = first[String](no_value)
    comptime assert type_of(procedure).Out == Tuple[type_of(None), String]
    var omitted = procedure((2, String("id")))
    assert_equal(omitted[1], "id")
    var explicit_adapter = second[String](as_unary(no_value))
    comptime assert type_of(explicit_adapter).Out == Tuple[String, type_of(None)]
    var adapter_result = explicit_adapter((String("id"), 2))
    assert_equal(adapter_result[0], "id")
    var no_error: def(var Int) raises Never thin = impossible_void
    var impossible_result = first[String](no_error)((2, String("id")))
    comptime assert type_of(impossible_result) == Tuple[type_of(None), String]
    assert_equal(impossible_result[1], "id")
    try: _ = second[String](fail_void)((String("id"), 9))
    except error: observed = error
    assert_equal(observed, 9)
    var left_calls = 0
    var right_calls = 0
    def mark_left(var value: Int) {mut left_calls}: left_calls += value
    def mark_right(var value: Int) {mut right_calls}: right_calls += value
    var both = flow(first[Int](as_unary(mark_left)), second[type_of(None)](as_unary(mark_right)))
    var no_values = both((2, 3))
    comptime assert type_of(no_values) == Tuple[type_of(None), type_of(None)]
    _ = no_values
    assert_equal(left_calls, 2)
    assert_equal(right_calls, 3)
    var ignored = first[String](unit)
    comptime assert type_of(ignored).Out == Tuple[NoneType, String]
    var result = ignored((2, String("id")))
    assert_equal(result[1], "id")

def main() raises:
    workflows()
    native()
