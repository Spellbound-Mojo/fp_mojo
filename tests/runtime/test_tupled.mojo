"""Reuse binary callbacks as unary pair transformations with their receiver modes."""
from fp.functions import tupled, flow, partial, pipeline
from fp.callables import BinarySignature, Unary, MutableUnary, OnceUnary
from test_composition import Swap
from test_fixed_callables import Join
from test_context_stages_combinations import ContextStagesPair
from test_mixed_composition import (add, sub, joined, label_sum, left_text, left_size,
    right_text, right_size, sizes, ignore, fail)
from test_native_binary_pointers import never, no_result, explicit_none
from std.testing import assert_equal

def pair(var value: Int) -> Tuple[Int, Int]: return (value, value + 1)
def biased(bias: Int, first: Int, second: Int) -> Int: return bias + first + second

def workflows() raises:
    var sum = tupled(add)
    assert_equal(sum((2, 3)), 5)
    assert_equal(pipeline[List[Tuple[Int, Int]]]([(1, 2), (3, 4)]).map(sum).get(), [3, 7])
    assert_equal(pipeline(Optional((2, 3))).map(sum).get_or(0), 5)
    assert_equal(pipeline(Optional(2)).map_n((Optional(3),), tupled(add)).get().value(), 5)
    assert_equal(flow(pair, sum^)(2), 5)
    var shifted = tupled(partial(biased, 10))
    assert_equal(shifted((1, 2)), 13)
    var custom = tupled(Swap())
    assert_equal(custom((2, String("a"))), "a2")
    assert_equal(custom.call_mut((2, String("a"))), "am2")
    assert_equal(custom^.call_once((2, String("a"))), "ao2")
    var mutable = tupled(Join(0))
    comptime assert conforms_to(type_of(mutable), MutableUnary)
    comptime assert not conforms_to(type_of(mutable), Unary)
    assert_equal(mutable.call_mut((2, 3)), 7)
    assert_equal(mutable.call_mut((2, 3)), 8)
    var once = tupled(ContextStagesPair())
    comptime assert conforms_to(type_of(once), OnceUnary)
    comptime assert not conforms_to(type_of(once), MutableUnary)
    assert_equal(once^.call_once((2, 3)), 5)
    var offset = 7
    def captured(var first: Int, var second: Int) {offset} -> Int: return first + second + offset
    var callback = tupled(BinarySignature[Int, Int, Int].capture(captured))
    assert_equal(callback((2, 3)), 12)

def pointers() raises:
    var rrr: def(var Int, var Int) thin -> Int = add
    var sum = tupled(rrr)
    rrr = sub
    assert_equal(sum((2, 3)), 5)
    assert_equal(tupled(rrr)((2, 3)), -1)
    var rrm: def(var Int, var Int) thin -> String = label_sum
    var mrm: def(var String, var Int) thin -> String = left_text
    var mrr: def(var String, var Int) thin -> Int = left_size
    var rmm: def(var Int, var String) thin -> String = right_text
    var rmr: def(var Int, var String) thin -> Int = right_size
    var mmm: def(var String, var String) thin -> String = joined
    var mmr: def(var String, var String) thin -> Int = sizes
    assert_equal(tupled(rrm)((2, 3)), "5")
    assert_equal(tupled(mrm)((String("a"), 2)), "a2")
    assert_equal(tupled(mrr)((String("ab"), 3)), 5)
    assert_equal(tupled(rmm)((2, String("b"))), "2b")
    assert_equal(tupled(rmr)((2, String("abc"))), 5)
    assert_equal(tupled(mmm)((String("ab"), String("cd"))), "abcd")
    assert_equal(tupled(mmr)((String("ab"), String("c"))), 3)

def effects() raises:
    var raising: def(var Int, var Int) raises Int thin -> Int = fail
    var callback = tupled(raising)
    comptime assert type_of(callback).Error == Int
    var observed = 0
    try: _ = callback((2, 3))
    except error: observed = error
    assert_equal(observed, 5)
    var impossible: def(var Int, var Int) raises Never thin -> Int = never
    assert_equal(tupled(impossible)((2, 3)), 5)
    var no_value: def(var Int, var Int) thin = ignore
    var procedure = tupled(no_value)
    comptime assert type_of(procedure).Out == type_of(None)
    procedure((2, 3))
    var unit = tupled(explicit_none)
    comptime assert type_of(unit).Out == NoneType
    _ = unit((2, 3))
    var error_void: def(var Int, var Int) raises Int thin = no_result
    try: tupled(error_void)((3, 4))
    except error: observed = error
    assert_equal(observed, 7)

def main() raises:
    workflows()
    pointers()
    effects()
