"""Mixed two-stage composition preserves native signatures and receiver modes."""
from fp.functions import flow, compose, partial, Identity, as_unary, pipeline, flip
from fp.iteration import iterated
from fp.callables import Binary, Thunk, Unary, MutableUnary, OnceUnary
from test_composition import Counter, Once
from std.testing import assert_equal

def add(var left: Int, var right: Int) -> Int: return left + right
def twice(var value: Int) -> Int: return value * 2
def plus(bias: Int, value: Int) -> Int: return bias + value
def seven() -> Int: return 7
def text(var value: Int) -> String: return String(value)
def length(var value: String) -> Int: return value.byte_length()
def joined(var left: String, var right: String) -> String: return left + right
def fail(var left: Int, var right: Int) raises Int -> Int: raise left + right
def never(var value: Int) raises Never -> Int: return value + 1
def sub(var left: Int, var right: Int) -> Int: return left - right
def label_sum(var left: Int, var right: Int) -> String: return String(left + right)
def left_text(var left: String, var right: Int) -> String: return left + String(right)
def left_size(var left: String, var right: Int) -> Int: return left.byte_length() + right
def right_text(var left: Int, var right: String) -> String: return String(left) + right
def right_size(var left: Int, var right: String) -> Int: return left + right.byte_length()
def sizes(var left: String, var right: String) -> Int: return left.byte_length() + right.byte_length()
def discard(var value: Int): _ = value
def none(var value: Int) -> NoneType:
    _ = value
    return None
def done(): pass
def empty_text() -> String: return String("ready")
def raise_void(var value: Int) raises Int: raise value
def ignore(var left: Int, var right: Int):
    _ = left
    _ = right

def forwarded[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R, var first: A, var second: B
) -> R:
    var chain = flow(function, Identity[R]())
    return chain(first^, second^)

def pure() raises:
    var forward = flow(add, partial(plus, 1))
    var backward = compose(partial(plus, 1), add)
    comptime assert conforms_to(type_of(forward), Binary)
    assert_equal(forward(2, 3), 6)
    assert_equal(backward(2, 3), 6)
    assert_equal(iterated(range(1, 4)).scan_left(forward, 0).collect_list(), [0, 2, 5, 9])
    var unary = flow(twice, partial(plus, 1))
    assert_equal(pipeline(Optional(3)).map(unary).get_or(0), 7)
    var thunk = flow(seven, partial(plus, 1))
    comptime assert conforms_to(type_of(thunk), Thunk)
    assert_equal(thunk(), 8)
    assert_equal(compose(partial(plus, 1), seven)(), 8)
    assert_equal(flow(partial(plus, 1), twice)(3), 8)
    assert_equal(compose(twice, partial(plus, 1))(3), 8)
    assert_equal(flow(flip(add), twice)(2, 3), 10)
    assert_equal(compose(twice, flip(add))(2, 3), 10)
    assert_equal(flow(partial(seven), twice)(), 14)
    assert_equal(compose(twice, partial(seven))(), 14)
    assert_equal(flow(twice, flow(partial(plus, 1), twice))(3), 14)
    var offset = 10
    def captured(var value: Int) {offset} -> Int: return value + offset
    assert_equal(flow(twice, as_unary(captured))(3), 16)
    assert_equal(flow(as_unary(captured), twice)(3), 26)
    var mutable = flow(twice, Counter(0))
    comptime assert conforms_to(type_of(mutable), MutableUnary)
    comptime assert not conforms_to(type_of(mutable), Unary)
    assert_equal(mutable.call_mut(3), 7)
    assert_equal(mutable.call_mut(3), 8)
    var consuming = compose(twice, Once(4))
    comptime assert conforms_to(type_of(consuming), OnceUnary)
    comptime assert not conforms_to(type_of(consuming), MutableUnary)
    assert_equal(consuming^.call_once(3), 14)

def pointers() raises:
    var binary: def(var Int, var Int) thin -> Int = add
    var unary: def(var Int) thin -> Int = twice
    var thunk: def() thin -> Int = seven
    var to_text: def(var Int) thin -> String = text
    var to_length: def(var String) thin -> Int = length
    var concatenate: def(var String, var String) thin -> String = joined
    var copied = flow(binary, Identity[Int]())
    binary = sub
    assert_equal(copied(2, 3), 5)
    assert_equal(flow(binary, Identity[Int]())(2, 3), -1)
    binary = add
    assert_equal(compose(Identity[Int](), binary)(2, 3), 5)
    assert_equal(flow(unary, Identity[Int]())(3), 6)
    assert_equal(flow(thunk, Identity[Int]())(), 7)
    assert_equal(flow(Identity[Int](), unary)(3), 6)
    assert_equal(compose(unary, Identity[Int]())(3), 6)
    assert_equal(flow(to_text, Identity[String]())(12), "12")
    assert_equal(flow(Identity[Int](), to_text)(12), "12")
    assert_equal(flow(to_length, Identity[Int]())("abc"), 3)
    assert_equal(flow(concatenate, Identity[String]())("ab", "cd"), "abcd")
    var rrm: def(var Int, var Int) thin -> String = label_sum
    var mrm: def(var String, var Int) thin -> String = left_text
    var mrr: def(var String, var Int) thin -> Int = left_size
    var rmm: def(var Int, var String) thin -> String = right_text
    var rmr: def(var Int, var String) thin -> Int = right_size
    var mmr: def(var String, var String) thin -> Int = sizes
    assert_equal(flow(rrm, Identity[String]())(2, 3), "5")
    assert_equal(compose(Identity[String](), mrm)("a", 2), "a2")
    assert_equal(flow(mrr, Identity[Int]())("ab", 3), 5)
    assert_equal(compose(Identity[String](), rmm)(2, "b"), "2b")
    assert_equal(flow(rmr, Identity[Int]())(2, "abc"), 5)
    assert_equal(compose(Identity[Int](), mmr)("ab", "c"), 3)
    assert_equal(flow(Identity[String](), to_length)("abc"), 3)
    assert_equal(forwarded(add, 2, 3), 5)
    assert_equal(forwarded(joined, String("a"), String("b")), "ab")
    var raised: def(var Int, var Int) raises Int thin -> Int = fail
    for reverse in range(2):
        var observed = 0
        try:
            if reverse: _ = compose(Identity[Int](), raised)(2, 3)
            else: _ = flow(raised, Identity[Int]())(2, 3)
        except error: observed = error
        assert_equal(observed, 5)
    var impossible: def(var Int) raises Never thin -> Int = never
    assert_equal(flow(impossible, Identity[Int]())(3), 4)
    assert_equal(flow(Identity[Int](), impossible)(3), 4)
    var nothing: def(var Int, var Int) thin = ignore
    var void_chain = flow(nothing, Identity[type_of(None)]())
    comptime assert type_of(void_chain).Out == type_of(None)
    void_chain(1, 2)
    flow(ignore, Identity[type_of(None)]())(1, 2)
    flow(done, Identity[type_of(None)]())()
    compose(discard, Identity[Int]())(3)
    flow(none, Identity[NoneType]())(3)
    flow(Identity[Int](), none)(3)
    var ready: def() thin -> String = empty_text
    assert_equal(flow(ready, Identity[String]())(), "ready")
    var void_error: def(var Int) raises Int thin = raise_void
    var raised_void = flow(Identity[Int](), void_error)
    var observed = 0
    try: raised_void(4)
    except error: observed = error
    assert_equal(observed, 4)

def main() raises:
    pure()
    pointers()
