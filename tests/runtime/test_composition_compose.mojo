"""Adapt the entry of saved function chains without nested old stages."""
from fp.functions import flow, compose, partial, flip, Identity, pipeline
from fp.iteration import iterated
from fp.callables import Thunk, Unary, Binary
from test_composition_then import plus, seven, scale, text, size, suffix, never, discard, none
from test_mixed_composition import (add, sub, joined, label_sum, left_text, left_size,
    right_text, right_size, sizes, done, empty_text, ignore, fail, raise_void)
from std.testing import assert_equal

def forwarded[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R, var first: A, var second: B
) -> R:
    return flow(Identity[R](), Identity[R]()).compose(function)(first^, second^)

def entries() raises:
    var forward = flow(plus, partial(scale, 2)).compose(add)
    var reverse = compose(partial(scale, 2), plus).compose(add)
    comptime assert type_of(forward).Fs.length == 3
    comptime assert type_of(reverse).Fs.length == 3
    comptime assert conforms_to(type_of(forward), Binary)
    assert_equal(forward(2, 3), 12)
    assert_equal(reverse(2, 3), 12)
    assert_equal(iterated(range(1, 3)).scan_left(reverse, 0).collect_list(), [0, 4, 14])
    var thunk = flow(plus, partial(scale, 2)).compose(seven)
    comptime assert conforms_to(type_of(thunk), Thunk)
    assert_equal(thunk(), 16)
    assert_equal(compose(partial(scale, 2), plus).compose(partial(seven))(), 16)
    assert_equal(flow(plus, partial(scale, 2)).compose(flip(sub))(2, 5), 8)
    var unary = flow(plus, partial(scale, 2)).compose(plus).then(plus).compose(plus)
    comptime assert type_of(unary).Fs.length == 5
    comptime assert conforms_to(type_of(unary), Unary)
    assert_equal(pipeline[Int]([1, 2]).map(unary).get(), [9, 11])
    var mirrored = compose(partial(scale, 2), plus).compose(plus).then(plus).compose(plus)
    assert_equal(mirrored(1), 9)
    var deep = flow(plus, plus).compose(plus).compose(plus).compose(plus).compose(plus).compose(plus).compose(plus).compose(plus).compose(plus).compose(plus).compose(plus)
    comptime assert type_of(deep).Fs.length == 12
    assert_equal(deep(0), 12)
    # Explicitly grouped new stages remain grouped; extending the old chain is flat.
    var grouped = flow(plus, plus).compose(flow(plus, plus))
    comptime assert type_of(grouped).Fs.length == 3
    assert_equal(grouped(0), 4)

def pointers() raises:
    var binary: def(var Int, var Int) thin -> Int = add
    var owned = flow(Identity[Int](), Identity[Int]()).compose(binary)
    binary = sub
    assert_equal(owned(2, 3), 5)
    assert_equal(flow(Identity[Int](), Identity[Int]()).compose(binary)(2, 3), -1)
    var rr: def(var Int) thin -> Int = plus
    var rm: def(var Int) thin -> String = text
    var mr: def(var String) thin -> Int = size
    var mm: def(var String) thin -> String = suffix
    assert_equal(flow(Identity[Int](), Identity[Int]()).compose(rr)(3), 4)
    assert_equal(compose(Identity[String](), Identity[String]()).compose(rm)(3), "3")
    assert_equal(flow(Identity[Int](), Identity[Int]()).compose(mr)("abc"), 3)
    assert_equal(compose(Identity[String](), Identity[String]()).compose(mm)("a"), "a!")
    var rrm: def(var Int, var Int) thin -> String = label_sum
    var mrm: def(var String, var Int) thin -> String = left_text
    var mrr: def(var String, var Int) thin -> Int = left_size
    var rmm: def(var Int, var String) thin -> String = right_text
    var rmr: def(var Int, var String) thin -> Int = right_size
    var mmm: def(var String, var String) thin -> String = joined
    var mmr: def(var String, var String) thin -> Int = sizes
    assert_equal(flow(Identity[String](), Identity[String]()).compose(rrm)(2, 3), "5")
    assert_equal(compose(Identity[String](), Identity[String]()).compose(mrm)("a", 2), "a2")
    assert_equal(flow(Identity[Int](), Identity[Int]()).compose(mrr)("ab", 3), 5)
    assert_equal(compose(Identity[String](), Identity[String]()).compose(rmm)(2, "b"), "2b")
    assert_equal(flow(Identity[Int](), Identity[Int]()).compose(rmr)(2, "abc"), 5)
    assert_equal(compose(Identity[String](), Identity[String]()).compose(mmm)("ab", "cd"), "abcd")
    assert_equal(flow(Identity[Int](), Identity[Int]()).compose(mmr)("ab", "c"), 3)
    var r: def() thin -> Int = seven
    var m: def() thin -> String = empty_text
    assert_equal(flow(Identity[Int](), Identity[Int]()).compose(r)(), 7)
    assert_equal(compose(Identity[String](), Identity[String]()).compose(m)(), "ready")
    assert_equal(forwarded(add, 2, 3), 5)
    assert_equal(forwarded(joined, String("a"), String("b")), "ab")

def effects() raises:
    var pointer: def(var Int, var Int) raises Int thin -> Int = fail
    var failure = compose(Identity[Int](), plus).compose(pointer)
    var observed = 0
    try: _ = failure(2, 3)
    except error: observed = error
    assert_equal(observed, 5)
    var impossible: def(var Int) raises Never thin -> Int = never
    assert_equal(flow(plus, plus).compose(impossible)(2), 5)
    var no_value: def(var Int) thin = discard
    var procedure = flow(Identity[type_of(None)](), Identity[type_of(None)]()).compose(no_value)
    comptime assert type_of(procedure).Out == type_of(None)
    procedure(2)
    var nothing: def(var Int, var Int) thin = ignore
    compose(Identity[type_of(None)](), Identity[type_of(None)]()).compose(nothing)(1, 2)
    flow(Identity[type_of(None)](), Identity[type_of(None)]()).compose(done)()
    var unit = flow(Identity[NoneType](), Identity[NoneType]()).compose(none)
    comptime assert type_of(unit).Out == NoneType
    _ = unit(2)
    var void_error: def(var Int) raises Int thin = raise_void
    try: flow(Identity[type_of(None)](), Identity[type_of(None)]()).compose(void_error)(4)
    except error: observed = error
    assert_equal(observed, 4)

def main() raises:
    entries()
    pointers()
    effects()
