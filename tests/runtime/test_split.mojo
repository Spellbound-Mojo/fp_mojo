"""Inferred pair transforms compose native and library callbacks in every receiver mode."""
from fp.functions import split, as_unary, tupled, partial, pipeline, Split
from fp.callables import Unary, MutableUnary, OnceUnary
from fp.iteration import iterated
from test_pair_projections import (increment, decrement, render, decorate, size,
    scaled, fail, never, no_value, impossible_void, fail_void, unit)
from test_fixed_callables import Tally, Spend, Token
from test_repeatable_mapping import Dual
from std.testing import assert_equal

def generic[A: Movable & Deinitable, R: Movable & Deinitable,
            B: Movable & Deinitable, S: Movable & Deinitable](
    left: def(var A) thin -> R, right: def(var B) thin -> S,
    var a: A, var b: B
) -> Tuple[R, S]:
    return split(left, right)((a^, b^))

def native() raises:
    # Exercise both register and memory input/result ABIs in both positions.
    assert_equal(split(increment, increment)((2, 3)), (3, 4))
    assert_equal(split(increment, render)((2, 3)), (3, String("3")))
    assert_equal(split(increment, size)((2, String("abc"))), (3, 3))
    assert_equal(split(increment, decorate)((2, String("a"))), (3, String("a!")))
    assert_equal(split(render, increment)((2, 3)), (String("2"), 4))
    assert_equal(split(render, render)((2, 3)), (String("2"), String("3")))
    assert_equal(split(render, size)((2, String("abc"))), (String("2"), 3))
    assert_equal(split(render, decorate)((2, String("a"))), (String("2"), String("a!")))
    assert_equal(split(size, increment)((String("ab"), 3)), (2, 4))
    assert_equal(split(size, render)((String("ab"), 3)), (2, String("3")))
    assert_equal(split(size, size)((String("ab"), String("abc"))), (2, 3))
    assert_equal(split(size, decorate)((String("ab"), String("a"))), (2, String("a!")))
    assert_equal(split(decorate, increment)((String("a"), 3)), (String("a!"), 4))
    assert_equal(split(decorate, render)((String("a"), 3)), (String("a!"), String("3")))
    assert_equal(split(decorate, size)((String("a"), String("abc"))), (String("a!"), 3))
    assert_equal(split(decorate, decorate)((String("a"), String("b"))), (String("a!"), String("b!")))
    assert_equal(generic(increment, decorate, 2, String("a")), (3, String("a!")))
    var left: def(var Int) thin -> Int = increment
    var right: def(var String) thin -> String = decorate
    var saved = split(left, right)
    left = decrement
    assert_equal(saved((2, String("a"))), (3, String("a!")))
    assert_equal(split(left, right)((2, String("a"))), (1, String("a!")))
    assert_equal(split(as_unary(render), increment)((2, 3)), (String("2"), 4))
    assert_equal(split(render, as_unary(increment))((2, 3)), (String("2"), 4))

def report(var label: String, var amount: Int) -> String:
    return label + ":" + String(amount)

def workflows() raises:
    var callback = split(partial(scaled, 3), partial(scaled, 4))
    var source: List[Tuple[Int, Int]] = [(1, 2), (2, 3)]
    assert_equal(pipeline(source^).map(callback).get(), [(3, 8), (6, 12)])
    assert_equal(callback((3, 4)), (9, 16))
    var composed = split(render, increment).then(tupled(report))
    assert_equal(composed((2, 3)), "2:4")
    var moving = split(Tally(0), Tally(10))
    comptime assert conforms_to(type_of(moving), MutableUnary)
    comptime assert not conforms_to(type_of(moving), Unary)
    var values: List[Tuple[Int, Int]] = [(1, 2), (1, 2)]
    assert_equal(iterated(values^).map(moving^).collect_list(), [(11, 31), (12, 32)])
    var left_mutable = split(Tally(0), increment)
    assert_equal(left_mutable.call_mut((1, 2)), (11, 3))
    var right_mutable = split(increment, Tally(0))
    assert_equal(right_mutable.call_mut((1, 2)), (2, 21))
    var once = split(Spend(Token(4)), Spend(Token(5)))
    comptime assert conforms_to(type_of(once), OnceUnary)
    comptime assert not conforms_to(type_of(once), MutableUnary)
    assert_equal(once^.call_once((1, 2)), (5, 7))
    var dual = split(Dual(0), Dual(0))
    assert_equal(dual((1, 2)), (101, 102))
    assert_equal(dual.call_mut((1, 2)), (202, 203))
    assert_equal(dual^.call_once((1, 2)), (901, 902))
    var offset = 4
    def captured(var value: Int) {offset} -> Int: return value + offset
    assert_equal(split(as_unary(captured), render)((2, 3)), (6, String("3")))

def effects() raises:
    var observed = 0
    var failed = split(fail, never)
    comptime assert type_of(failed).Error == Int
    try: _ = failed((7, 3))
    except error: observed = error
    assert_equal(observed, 7)
    try: _ = split(never, fail)((7, 3))
    except error: observed = error
    assert_equal(observed, 3)
    assert_equal(split(never, increment)((2, 3)), (3, 4))
    var left_calls = 0
    var right_calls = 0
    def mark_left(var value: Int) {mut left_calls}: left_calls += value
    def mark_right(var value: Int) {mut right_calls}: right_calls += value
    var omitted = split(as_unary(mark_left), as_unary(mark_right))((2, 3))
    comptime assert type_of(omitted) == Tuple[type_of(None), type_of(None)]
    _ = omitted
    assert_equal(left_calls, 2)
    assert_equal(right_calls, 3)
    var native_void = split(no_value, impossible_void)((2, 3))
    comptime assert type_of(native_void) == Tuple[type_of(None), type_of(None)]
    _ = native_void
    var units = split(unit, no_value)((2, 3))
    comptime assert type_of(units) == Tuple[NoneType, type_of(None)]
    _ = units
    try: _ = split(no_value, fail_void)((7, 3))
    except error: observed = error
    assert_equal(observed, 3)

def main() raises:
    native()
    workflows()
    effects()
