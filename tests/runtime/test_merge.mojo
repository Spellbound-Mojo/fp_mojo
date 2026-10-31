"""Cats-style merge infers one input and retains callback capabilities and effects."""
from fp.functions import merge, as_unary, tupled, partial, pipeline
from fp.callables import Unary, MutableUnary, OnceUnary
from fp.iteration import iterated
from test_pair_projections import (increment, decrement, render, decorate, size,
    scaled, fail, never, no_value, impossible_void, fail_void, unit)
from test_fixed_callables import Tally, Spend, Token
from test_repeatable_mapping import Dual
from test_split import report
from std.testing import assert_equal

def generic[A: Copyable & Deinitable, R: Movable & Deinitable, S: Movable & Deinitable](
    left: def(var A) thin -> R, right: def(var A) thin -> S, var value: A
) -> Tuple[R, S]:
    return merge(left, right)(value^)

def main() raises:
    assert_equal(merge(increment, increment)(2), (3, 3))
    assert_equal(merge(increment, render)(2), (3, String("2")))
    assert_equal(merge(render, increment)(2), (String("2"), 3))
    assert_equal(merge(render, render)(2), (String("2"), String("2")))
    assert_equal(merge(size, size)(String("ab")), (2, 2))
    assert_equal(merge(size, decorate)(String("ab")), (2, String("ab!")))
    assert_equal(merge(decorate, size)(String("ab")), (String("ab!"), 2))
    assert_equal(merge(decorate, decorate)(String("ab")), (String("ab!"), String("ab!")))
    assert_equal(generic(size, decorate, String("ab")), (2, String("ab!")))
    var pointer: def(var Int) thin -> Int = increment
    var saved = merge(pointer, render)
    pointer = decrement
    assert_equal(saved(2), (3, String("2")))
    assert_equal(merge(pointer, render)(2), (1, String("2")))
    assert_equal(merge(as_unary(render), increment)(2), (String("2"), 3))
    assert_equal(merge(render, as_unary(increment))(2), (String("2"), 3))
    var reusable = merge(partial(scaled, 3), partial(scaled, 4))
    comptime assert type_of(reusable).Fs.length == 3
    assert_equal(pipeline[List[Int]]([1, 2]).map(reusable).get(), [(3, 4), (6, 8)])
    assert_equal(reusable(3), (9, 12))
    var composed = merge(render, increment).then(tupled(report))
    comptime assert type_of(composed).Fs.length == 4
    assert_equal(composed(2), "2:3")
    var mutable = merge(Tally(0), Tally(10))
    comptime assert conforms_to(type_of(mutable), MutableUnary)
    comptime assert not conforms_to(type_of(mutable), Unary)
    var values: List[Int] = [1, 2]
    assert_equal(iterated(values^).map(mutable^).collect_list(), [(11, 21), (22, 32)])
    var mixed_left = merge(Tally(0), increment)
    var mixed_right = merge(increment, Tally(0))
    assert_equal(mixed_left.call_mut(1), (11, 2))
    assert_equal(mixed_right.call_mut(1), (2, 11))
    var once = merge(Spend(Token(4)), Spend(Token(5)))
    comptime assert conforms_to(type_of(once), OnceUnary)
    comptime assert not conforms_to(type_of(once), MutableUnary)
    assert_equal(once^.call_once(1), (5, 6))
    var dual = merge(Dual(0), Dual(0))
    assert_equal(dual(1), (101, 101))
    assert_equal(dual.call_mut(1), (202, 202))
    assert_equal(dual^.call_once(1), (901, 901))
    var offset = 4
    def captured(var value: Int) {offset} -> Int: return value + offset
    assert_equal(merge(as_unary(captured), render)(2), (6, String("2")))
    var observed = 0
    var failed = merge(fail, never)
    comptime assert type_of(failed).Error == Int
    try: _ = failed(7)
    except error: observed = error
    assert_equal(observed, 7)
    try: _ = merge(never, fail)(3)
    except error: observed = error
    assert_equal(observed, 3)
    assert_equal(merge(never, increment)(2), (3, 3))
    var omitted = merge(no_value, impossible_void)(2)
    comptime assert type_of(omitted) == Tuple[type_of(None), type_of(None)]
    _ = omitted
    var units = merge(unit, no_value)(2)
    comptime assert type_of(units) == Tuple[NoneType, type_of(None)]
    _ = units
    try: _ = merge(no_value, fail_void)(3)
    except error: observed = error
    assert_equal(observed, 3)
