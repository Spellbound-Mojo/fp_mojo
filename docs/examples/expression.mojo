"""A recursive expression type: evaluate, render and simplify it with clauses.

Each clause handles one constructor. A field declared with the result type
arrives already evaluated; a field declared as `Expr` arrives as it is. `If`
continues with the branch it takes, so the other branch is never evaluated.
"""
import fp
from fp.adt import Data, Cases, Node, Value
from fp.matching import Next


@fieldwise_init
struct Num(Copyable, Equatable):
    var value: Int


@fieldwise_init
struct Add[R: Value](Movable):
    var left: Self.R
    var right: Self.R


@fieldwise_init
struct Mul[R: Value](Movable):
    var left: Self.R
    var right: Self.R


@fieldwise_init
struct If[C: Value, B: Value](Movable):
    var cond: Self.C
    var then: Self.B
    var other: Self.B


struct Expr(Data):
    comptime Layer[R: Value] = Cases[Num, Add[R], Mul[R], If[R, R]]


comptime E = Node[Expr]


def evaluate(e: E) -> Int:
    return fp.match(e,
        lambda (n: Num) -> Int: n.value,
        lambda (a: Add[Int]) -> Int: a.left + a.right,
        lambda (m: Mul[Int]) -> Int: m.left * m.right,
        lambda (c: If[Int, E]) -> Next[E]: Next(c.then if c.cond != 0 else c.other))


def render(e: E) -> String:
    return fp.match(e,
        lambda (n: Num) -> String: String(n.value),
        lambda (a: Add[String]) -> String: "(" + a.left + " + " + a.right + ")",
        lambda (m: Mul[String]) -> String: m.left + " * " + m.right,
        lambda (c: If[String, String]) -> String: "if " + c.cond + " then " + c.then + " else " + c.other)


def simplify(e: E) -> E:
    """Remove additions of zero and multiplications by one, bottom-up."""
    return fp.rewrite(e,
        fp.when[lambda (a: Add[E]) -> Bool: a.left == Num(0), lambda (a: Add[E]) -> E: a.right],
        fp.when[lambda (a: Add[E]) -> Bool: a.right == Num(0), lambda (a: Add[E]) -> E: a.left],
        fp.when[lambda (m: Mul[E]) -> Bool: m.left == Num(1), lambda (m: Mul[E]) -> E: m.right],
        fp.when[lambda (m: Mul[E]) -> Bool: m.right == Num(1), lambda (m: Mul[E]) -> E: m.left])


def main():
    var zero: E = Num(0)
    var one: E = Num(1)
    var x: E = Add(E(Mul(one, E(Num(6)))), E(Add(E(Num(4)), zero)))
    print(render(x), "=", evaluate(x))
    var y = simplify(x)
    print(render(y), "=", evaluate(y))

    # The branch not taken is never evaluated, however large it is.
    var big: E = one
    for _ in range(40):
        big = Mul(big, big)
    print(evaluate(E(If(zero, big, E(Num(7))))))

    # A value shared by both operands is evaluated once per match.
    var shared: E = Num(2)
    for _ in range(61):
        shared = Add(shared, shared)
    print(evaluate(shared))

    # Depth is limited only by memory.
    var deep: E = zero
    for _ in range(1_000_000):
        deep = Add(deep, one)
    print(evaluate(deep))
