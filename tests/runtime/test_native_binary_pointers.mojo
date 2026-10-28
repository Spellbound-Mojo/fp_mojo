"""Reusable native binary pointers keep signatures, views and extraction exact."""
from fp.callables import as_binary, NativeBinary, Binary
from fp.functions import flow, compose, partial, piped
from fp.iteration import iterated
from test_mixed_composition import (add, sub, joined, label_sum, left_text, left_size,
    right_text, right_size, sizes, ignore, fail)
from test_composition_then import plus, scale
from test_scan_callback_views import pair
from std.testing import assert_equal

def generic[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R, var first: A, var second: B
) -> R:
    return as_binary(function)(first^, second^)

def read_join(first: String, second: String) -> String: return first + second

def never(var first: Int, var second: Int) raises Never -> Int: return first + second
def no_result(var first: Int, var second: Int) raises Int: raise first + second
def explicit_none(var first: Int, var second: Int) -> NoneType:
    _ = first
    _ = second
    return None

def pointers() raises:
    var rrr: def(var Int, var Int) thin -> Int = add
    var callback = as_binary(rrr)
    comptime assert type_of(callback) == NativeBinary[Int, Int, Int, Never, type_of(rrr), False]
    comptime assert conforms_to(type_of(callback), Binary)
    comptime assert conforms_to(type_of(callback), ImplicitlyCopyable)
    assert_equal(callback.copy()(2, 3), 5)
    rrr = sub
    assert_equal(callback(2, 3), 5)
    assert_equal(callback.function()(2, 3), 5)
    var extracted = callback^.into_function()
    comptime assert type_of(extracted) == type_of(rrr)
    assert_equal(extracted(2, 3), 5)
    var changed = as_binary(add)
    changed.function() = rrr
    assert_equal(changed(2, 3), -1)
    assert_equal(as_binary[A=Int, B=Int, R=Int](rrr)(2, 3), -1)
    var rrm: def(var Int, var Int) thin -> String = label_sum
    var mrm: def(var String, var Int) thin -> String = left_text
    var mrr: def(var String, var Int) thin -> Int = left_size
    var rmm: def(var Int, var String) thin -> String = right_text
    var rmr: def(var Int, var String) thin -> Int = right_size
    var mmm: def(var String, var String) thin -> String = joined
    var mmr: def(var String, var String) thin -> Int = sizes
    assert_equal(as_binary(rrm)(2, 3), "5")
    assert_equal(as_binary(mrm)("a", 2), "a2")
    assert_equal(as_binary(mrr)("ab", 3), 5)
    assert_equal(as_binary(rmm)(2, "b"), "2b")
    assert_equal(as_binary(rmr)(2, "abc"), 5)
    assert_equal(as_binary(mmm)("ab", "cd"), "abcd")
    assert_equal(as_binary(mmr)("ab", "c"), 3)
    assert_equal(generic(add, 2, 3), 5)
    assert_equal(generic(joined, String("a"), String("b")), "ab")
    assert_equal(as_binary(read_join)("a", "b"), "ab")

def reuse() raises:
    var callback = as_binary(add)
    assert_equal(iterated(range(2)).zip_with(range(3, 5), callback).collect_list(), [3, 5])
    assert_equal(iterated(range(3)).map_with_index(callback).collect_list(), [0, 2, 4])
    assert_equal(iterated(range(1, 4)).scan_left(callback, 0).collect_list(), [0, 1, 3, 6])
    var step = as_binary(pair)
    assert_equal(iterated(range(3)).scan_map(step, 0).collect_list(), ["0", "2", "6"])
    assert_equal(iterated(range(2)).scan_map(step, 0).collect_list(), ["0", "2"])
    assert_equal(piped(List[Int]([1, 2, 3])).fold_left(callback, 0).get(), 6)
    assert_equal(callback(4, 5), 9)
    assert_equal(flow(callback.copy(), plus)(2, 3), 6)
    assert_equal(compose(partial(scale, 2), plus).compose(callback^)(2, 3), 12)

def errors() raises:
    var raising: def(var Int, var Int) raises Int thin -> Int = fail
    var callback = as_binary(raising)
    comptime assert type_of(callback).Error == Int
    var observed = 0
    try: _ = callback(2, 3)
    except error: observed = error
    assert_equal(observed, 5)
    var impossible: def(var Int, var Int) raises Never thin -> Int = never
    assert_equal(as_binary(impossible)(2, 3), 5)
    var void: def(var Int, var Int) thin = ignore
    var procedure = as_binary(void)
    comptime assert type_of(procedure).Out == type_of(None)
    procedure(1, 2)
    var unit = as_binary(explicit_none)
    comptime assert type_of(unit).Out == NoneType
    _ = unit(1, 2)
    var void_error: def(var Int, var Int) raises Int thin = no_result
    try: as_binary(void_error)(3, 4)
    except error: observed = error
    assert_equal(observed, 7)

def main() raises:
    pointers()
    reuse()
    errors()
