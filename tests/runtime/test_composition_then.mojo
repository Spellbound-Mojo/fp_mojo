"""Extend a reusable composition one stage at a time without nested prefixes."""
from fp.functions import flow, compose, partial, Identity, pipeline
from fp.iteration import iterated
from fp.data import Result, Err
from std.testing import assert_equal

def add(var first: Int, var second: Int) -> Int: return first + second
def scale(factor: Int, value: Int) -> Int: return factor * value
def plus(var value: Int) -> Int: return value + 1
def seven() -> Int: return 7
def text(var value: Int) -> String: return String(value)
def size(var value: String) -> Int: return value.byte_length()
def suffix(var value: String) -> String: return value + "!"
def reject(var value: Int) raises Int -> Int: raise value
def never(var value: Int) raises Never -> Int: return value + 1
def discard(var value: Int): _ = value
def none(var value: Int) -> NoneType:
    _ = value
    return None
def stored_error(var value: Int) -> Result[Int, String]: return Err(String(value))
def handle_stored(var value: Result[Int, String]) -> Int: return value^.get_or(99)

def generic[A: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A) thin -> R, var value: A
) -> R:
    var chain = flow(Identity[A](), Identity[A]()).then(function)
    return chain(value^)

def main() raises:
    var forward = flow(add, partial(scale, 2)).then(plus)
    comptime assert type_of(forward).Fs.length == 3
    assert_equal(forward(2, 3), 11)
    var reverse = compose(partial(scale, 2), add).then(plus)
    comptime assert type_of(reverse).Fs.length == 3
    assert_equal(reverse(2, 3), 11)
    var longer = forward^.then(partial(scale, 3)).then(plus)
    comptime assert type_of(longer).Fs.length == 5
    assert_equal(longer(2, 3), 34)
    var snapshots = iterated(range(1, 3)).scan_left(reverse, 0).collect_list()
    assert_equal(snapshots, [0, 3, 11])
    var thunk = flow(seven, partial(scale, 2)).then(plus)
    assert_equal(thunk(), 15)
    var unary = flow(plus, partial(scale, 2)).then(plus)
    assert_equal(pipeline[List[Int]]([1, 2]).map(unary).get(), [5, 7])
    var deep = flow(add, partial(scale, 2)).then(plus).then(plus).then(plus).then(plus).then(plus).then(plus).then(plus).then(plus).then(plus).then(plus)
    comptime assert type_of(deep).Fs.length == 12
    assert_equal(deep(2, 3), 20)
    var rr: def(var Int) thin -> Int = plus
    var rm: def(var Int) thin -> String = text
    var mr: def(var String) thin -> Int = size
    var mm: def(var String) thin -> String = suffix
    assert_equal(flow(Identity[Int](), Identity[Int]()).then(rr)(3), 4)
    assert_equal(compose(Identity[Int](), Identity[Int]()).then(rm)(3), "3")
    assert_equal(flow(Identity[String](), Identity[String]()).then(mr)("abc"), 3)
    assert_equal(compose(Identity[String](), Identity[String]()).then(mm)("a"), "a!")
    assert_equal(generic(text, 3), "3")
    assert_equal(generic(size, String("abc")), 3)
    var pointer: def(var Int) raises Int thin -> Int = reject
    var failure = flow(plus, partial(scale, 2)).then(pointer)
    var observed = 0
    try: _ = failure(2)
    except error: observed = error
    assert_equal(observed, 6)
    var impossible: def(var Int) raises Never thin -> Int = never
    assert_equal(flow(plus, partial(scale, 2)).then(impossible)(2), 7)
    var no_value: def(var Int) thin = discard
    var procedure = flow(plus, partial(scale, 2)).then(no_value)
    comptime assert type_of(procedure).Out == type_of(None)
    procedure(2)
    var unit = flow(plus, partial(scale, 2)).then(none)
    comptime assert type_of(unit).Out == NoneType
    _ = unit(2)
    assert_equal(flow(plus, stored_error).then(handle_stored)(2), 99)
