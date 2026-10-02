"""Compositions, flips and pipelines over native stages and library values."""
from fp.functions import Composition, Identity, flow, compose, flip, partial, pipe, as_unary
from fp.callables import (Unary, MutableUnary, OnceUnary, Binary, MutableBinary, OnceBinary,
    Thunk, MutableThunk, OnceThunk, call_once)
from fp.iteration import map, fold_left, collect_list
from fp.control import fori_loop
from fp.data import Result, Ok, Err
from fp.algebra import map as algebra_map, OptionalFamily
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


def twice(var x: Int) -> Int:
    return 2 * x


def inc(var x: Int) -> Int:
    return x + 1


def add(a: Int, b: Int) -> Int:
    return a + b


def sub(a: Int, b: Int) -> Int:
    return a - b


def sub3(a: Int, b: Int, c: Int) -> Int:
    return a - b - c


def seven() -> Int:
    return 7


def label(var x: Int) -> String:
    return "v=" + String(x)


@fieldwise_init
struct Bad(Movable, Writable):
    var code: Int


def check(var x: Int) raises Bad -> Int:
    if x < 0:
        raise Bad(x)
    return x


def checked_sub(a: Int, b: Int) raises Bad -> Int:
    if a < b:
        raise Bad(a - b)
    return a - b


@fieldwise_init
struct Counter(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var arg: Int) -> Int:
        self.calls += 1
        return arg + self.calls


@fieldwise_init
struct Once(OnceUnary):
    var bias: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int:
        return arg + self.bias


@fieldwise_init
struct Token(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct Wrap(Unary):
    var drops: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Token
    def call(self, var arg: Int) -> Token:
        return Token(arg, self.drops)


@fieldwise_init
struct Unwrap(Unary):
    comptime Arg = Token
    comptime Out = Int
    def call(self, var arg: Token) -> Int:
        return arg.value


@fieldwise_init
struct Swap(Binary, MutableBinary, OnceBinary):
    comptime First = Int
    comptime Second = String
    comptime Out = String
    def call(self, var first: Int, var second: String) -> String:
        return second + String(first)
    def call_mut(mut self, var first: Int, var second: String) -> String:
        return second + "m" + String(first)
    def call_once(deinit self, var first: Int, var second: String) -> String:
        return second + "o" + String(first)


def pipelines() raises:
    assert_equal(pipe(3, as_unary(twice), as_unary(inc)), 7)
    assert_equal(pipe(3, as_unary(twice), partial(add, 10)), 16)
    assert_equal(pipe(3, as_unary(twice), as_unary(label)), "v=6")
    assert_equal(pipe(3, flow(as_unary(twice), as_unary(inc))), 7)
    var code = 0
    try:
        _ = pipe(-2, as_unary(check), as_unary(twice))
    except error:
        code = error.code
    assert_equal(code, -2)


def compositions() raises:
    var forward = flow(as_unary(twice), as_unary(inc))
    assert_equal(forward(5), 11)
    assert_equal(forward.call(5), 11)
    var backward = compose(as_unary(twice), as_unary(inc))
    assert_equal(backward(5), 12)
    # The first-applied stage fixes the arity.
    var binary_first = flow(partial(add), as_unary(twice))
    assert_equal(binary_first(2, 3), 10)
    comptime assert conforms_to(type_of(binary_first), Binary)
    var thunk_first = flow(partial(seven), as_unary(inc))
    assert_equal(thunk_first(), 8)
    comptime assert conforms_to(type_of(thunk_first), Thunk)
    var composed_last = compose(as_unary(inc), partial(add))
    assert_equal(composed_last(1, 2), 4)
    # Zero and one component.
    assert_equal(Identity[Int]()(4), 4)
    assert_equal(flow[Int]()(9), 9)
    var single = flow(partial(add, 1))
    comptime assert not conforms_to(type_of(single), MutableUnary)
    assert_equal(single(2), 3)
    # Nesting and many stages.
    var nested = flow(forward^, as_unary(twice))
    assert_equal(nested(1), 6)
    var long = flow(as_unary(inc), as_unary(inc), as_unary(inc), as_unary(inc), as_unary(inc), as_unary(twice))
    assert_equal(long(0), 10)
    # A raised error stops the chain with its exact type.
    var failing = flow(as_unary(check), as_unary(twice))
    var code = 0
    try:
        _ = failing(-2)
    except error:
        code = error.code
    assert_equal(code, -2)


def receiver_modes() raises:
    comptime Shared = type_of(flow(as_unary(twice), as_unary(inc)))
    comptime assert conforms_to(Shared, Unary) and conforms_to(Shared, MutableUnary) and conforms_to(Shared, OnceUnary)
    var mutable = flow(Counter(0), as_unary(twice))
    comptime assert not conforms_to(type_of(mutable), Unary)
    comptime assert conforms_to(type_of(mutable), MutableUnary)
    assert_equal(mutable.call_mut(1), 4)
    assert_equal(mutable.call_mut(1), 6)
    var consuming = flow(as_unary(inc), Once(100))
    comptime assert not conforms_to(type_of(consuming), MutableUnary)
    assert_equal(consuming^.call_once(1), 102)
    assert_equal(call_once(flow(Counter(0), Once(10)), 5), 16)
    # Copyable only when every component is.
    comptime assert conforms_to(type_of(flow(partial(add, 1), as_unary(inc))), Copyable)
    comptime assert not conforms_to(type_of(flow(Counter(0), as_unary(inc))), Copyable)


def move_only() raises:
    var drops = ArcPointer(0)
    var chain = flow(Wrap(drops), Unwrap())
    assert_equal(chain(4), 4)
    assert_equal(chain(5), 5)
    assert_equal(drops[], 2)


def flips() raises:
    var s = flip(partial(sub))
    assert_equal(s(3, 10), 7)
    var sf = flip(sub)
    assert_equal(sf(3, 10), 7)
    var s3 = flip(sub3)
    assert_equal(s3(3, 10, 1), 6)
    var checked = flip(checked_sub)
    var code = 0
    try:
        _ = checked(5, 1)
    except error:
        code = error.code
    assert_equal(code, -4)
    # Receiver modes of a Binary target are kept.
    var swapped = flip(Swap())
    assert_equal(swapped.call(String("x"), 1), "x1")
    assert_equal(swapped.call_mut(String("x"), 2), "xm2")
    assert_equal(swapped^.call_once(String("x"), 3), "xo3")


def consumers() raises:
    # Compositions and partials are library values accepted by higher-order APIs.
    var xs: List[Int] = [1, 2, 3]
    var mapped = collect_list(map(flow(as_unary(twice), as_unary(inc)), iter(xs)))
    assert_equal(mapped[2], 7)
    assert_equal(fold_left(flow(partial(add), as_unary(twice)), 0, iter(xs)), 22)
    assert_equal(fori_loop(0, 3, flow(partial(add), as_unary(inc)), 0), 6)
    var err = Result[Int, Int](Err(4)).map_err(flow(as_unary(twice), as_unary(label)))
    assert_true(not err.is_ok())
    assert_equal(algebra_map[OptionalFamily](flow(as_unary(inc), as_unary(twice)), Optional(3)).value(), 8)


def main() raises:
    pipelines()
    compositions()
    receiver_modes()
    move_only()
    flips()
    consumers()
    print("composition: arities, receiver modes, errors, move-only values, flips and consumers")
