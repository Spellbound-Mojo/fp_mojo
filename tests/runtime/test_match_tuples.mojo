"""`fp.match` on two and three values: constructors, catch-alls, plain components and guards."""
import fp
from fp.adt import Data, Cases, Node, Value
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct TuplesNil(Copyable):
    pass


@fieldwise_init
struct TuplesCons[R: Value](Movable):
    var head: Int
    var tail: Self.R


struct TuplesList(Data):
    comptime Layer[R: Value] = Cases[TuplesNil, TuplesCons[R]]


comptime L = Node[TuplesList]


@fieldwise_init
struct TuplesRed(Copyable):
    pass


@fieldwise_init
struct TuplesGreen(Copyable):
    var shade: Int


struct TuplesColor(Data):
    comptime Layer[R: Value] = Cases[TuplesRed, TuplesGreen]


comptime C = Node[TuplesColor]


def same_head(a: L, b: L) -> Bool:
    return fp.match((a, b),
        lambda (x: TuplesNil, y: TuplesNil) -> Bool: True,
        fp.when[lambda (x: TuplesCons[L], y: TuplesCons[L]) -> Bool: x.head == y.head,
                lambda (x: TuplesCons[L], y: TuplesCons[L]) -> Bool: True],
        lambda (x: L, y: L) -> Bool: False)


def describe(c: C, l: L, limit: Int) -> String:
    return fp.match((c, l, limit),
        lambda (r: TuplesRed, n: TuplesNil, k: Int) -> String: "red, empty",
        fp.when[lambda (g: TuplesGreen, x: TuplesCons[L], k: Int) -> Bool: g.shade + x.head > k,
                lambda (g: TuplesGreen, x: TuplesCons[L], k: Int) -> String: "bright"],
        lambda (g: TuplesGreen, x: L, k: Int) -> String: "green " + String(g.shade),
        lambda (r: C, x: L, k: Int) -> String: "other")


def main() raises:
    var empty: L = TuplesNil()
    var one: L = TuplesCons(1, empty)
    var other: L = TuplesCons(1, one)
    var two: L = TuplesCons(2, empty)
    assert_true(same_head(empty, empty))
    assert_true(same_head(one, other))
    assert_false(same_head(one, two))
    assert_false(same_head(one, empty))
    assert_false(same_head(empty, two))

    var red: C = TuplesRed()
    var green: C = TuplesGreen(5)
    assert_equal(describe(red, empty, 0), "red, empty")
    assert_equal(describe(green, two, 3), "bright")
    assert_equal(describe(green, two, 10), "green 5")
    assert_equal(describe(green, empty, 0), "green 5")
    assert_equal(describe(red, two, 0), "other")
