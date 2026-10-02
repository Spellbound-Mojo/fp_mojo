"""`fp.rewrite`: bottom-up, single pass, guards, and unchanged values shared."""
import fp
from fp.adt import Data, Cases, Node, Value
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct RewriteNum(Copyable, Equatable):
    var value: Int


@fieldwise_init
struct RewriteAdd[R: Value](Movable):
    var left: Self.R
    var right: Self.R


@fieldwise_init
struct RewriteMul[R: Value](Movable):
    var left: Self.R
    var right: Self.R


struct RewriteExpr(Data):
    comptime Layer[R: Value] = Cases[RewriteNum, RewriteAdd[R], RewriteMul[R]]


comptime E = Node[RewriteExpr]


def simplify(x: E) -> E:
    return fp.rewrite(x,
        fp.when[lambda (a: RewriteAdd[E]) -> Bool: a.left == RewriteNum(0), lambda (a: RewriteAdd[E]) -> E: a.right],
        fp.when[lambda (a: RewriteAdd[E]) -> Bool: a.right == RewriteNum(0), lambda (a: RewriteAdd[E]) -> E: a.left],
        fp.when[lambda (m: RewriteMul[E]) -> Bool: m.left == RewriteNum(1), lambda (m: RewriteMul[E]) -> E: m.right])


def double(x: E) -> E:
    """Every number doubles; the other constructors are rebuilt."""
    return fp.rewrite(x, lambda (n: RewriteNum) -> E: RewriteNum(n.value * 2))


def value(x: E) -> Int:
    return fp.match(x,
        lambda (n: RewriteNum) -> Int: n.value,
        lambda (a: RewriteAdd[Int]) -> Int: a.left + a.right,
        lambda (m: RewriteMul[Int]) -> Int: m.left * m.right)


def main() raises:
    var zero: E = RewriteNum(0)
    var one: E = RewriteNum(1)
    var five: E = RewriteNum(5)
    var kept: E = RewriteMul(five, five)

    # Children are rewritten first: the inner sum becomes 5, then 1 * 5 becomes 5.
    var x: E = RewriteMul(one, E(RewriteAdd(zero, five)))
    var s = simplify(x)
    assert_true(s is five)

    # A value with nothing to simplify is returned as it is.
    var unchanged = simplify(kept)
    assert_true(unchanged is kept)

    # A changed child rebuilds its parents; unchanged siblings stay shared.
    var mixed: E = RewriteAdd(kept, E(RewriteAdd(five, zero)))
    var m = simplify(mixed)
    assert_false(m is mixed)
    assert_true(m[RewriteAdd[E]].left is kept)
    assert_true(m[RewriteAdd[E]].right is five)

    # The outer sum sees its left child already rewritten to 0.
    var twice: E = RewriteAdd(E(RewriteAdd(zero, zero)), one)
    var t = simplify(twice)
    assert_true(t is one)

    # A single pass: the doubled numbers are not doubled again.
    var d = double(RewriteAdd(E(RewriteMul(five, one)), E(RewriteNum(3))))
    assert_equal(value(d), 26)

    # A shared value is rewritten once and stays shared.
    var shared: E = RewriteAdd(five, five)
    var both: E = RewriteMul(shared, shared)
    var doubled = double(both)
    assert_true(doubled[RewriteMul[E]].left is doubled[RewriteMul[E]].right)
    assert_equal(value(doubled), 400)
