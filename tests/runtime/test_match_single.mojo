"""`fp.match` on one value: field delivery, Next, guards, catch-alls, order, context and sharing."""
import fp
from fp.adt import Data, Cases, Node, Value
from fp.matching import Next
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct SingleNum(Copyable, Equatable):
    var value: Int


@fieldwise_init
struct SingleAdd[R: Value](Movable):
    var left: Self.R
    var right: Self.R


@fieldwise_init
struct SingleIf[C: Value, B: Value](Movable):
    var cond: Self.C
    var then: Self.B
    var other: Self.B


@fieldwise_init
struct SingleSum[R: Value](Movable):
    var items: List[Self.R]


@fieldwise_init
struct SingleOpt[R: Value](Movable):
    var item: Optional[Self.R]


@fieldwise_init
struct SingleBoom(Copyable):
    var code: Int


struct SingleExpr(Data):
    comptime Layer[R: Value] = Cases[SingleNum, SingleAdd[R], SingleIf[R, R], SingleSum[R], SingleOpt[R], SingleBoom]


comptime X = Node[SingleExpr]


@fieldwise_init
struct SingleFailure(Movable):
    var code: Int


def boom(b: SingleBoom) raises SingleFailure -> Int:
    raise SingleFailure(b.code)


def evaluate(x: X) raises SingleFailure -> Int:
    return fp.match(x,
        lambda (n: SingleNum) -> Int: n.value,
        lambda (a: SingleAdd[Int]) -> Int: a.left + a.right,
        lambda (c: SingleIf[Int, X]) -> Next[X]: Next(c.then if c.cond != 0 else c.other),
        lambda (s: SingleSum[Int]) -> Int: sum_of(s.items),
        lambda (o: SingleOpt[Int]) -> Int: o.item.value() if o.item else -1,
        boom)


def value_of(x: X) -> Int:
    """The value, or -1000 minus the failure code when a clause raised."""
    try:
        return evaluate(x)
    except error:
        return -1000 - error.code


def sum_of(items: List[Int]) -> Int:
    var total = 0
    for item in items:
        total += item
    return total


def describe(x: X) -> String:
    """Guards, a catch-all, and fields as stored."""
    return fp.match(x,
        fp.when[lambda (a: SingleAdd[X]) -> Bool: a.left == SingleNum(0), lambda (a: SingleAdd[X]) -> String: "zero plus"],
        lambda (a: SingleAdd[X]) -> String: "plus",
        lambda (n: SingleNum) -> String: "number " + String(n.value),
        lambda (e: X) -> String: "other")


def guarded_sum(x: X) -> Int:
    """A guard over evaluated fields that declines, then a clause that cannot."""
    return fp.match(x,
        lambda (n: SingleNum) -> Int: n.value,
        fp.when[lambda (a: SingleAdd[Int]) -> Bool: a.left > 100, lambda (a: SingleAdd[Int]) -> Int: 100],
        lambda (a: SingleAdd[Int]) -> Int: a.left + a.right,
        lambda (e: X) -> Int: 0)


def scaled(x: X, factor: Int) -> Int:
    return fp.match(x,
        lambda (n: SingleNum, k: Int) -> Int: n.value * k,
        lambda (a: SingleAdd[Int], k: Int) -> Int: a.left + a.right,
        lambda (e: X, k: Int) -> Int: 0,
        context=factor)


def counted(counter: ArcPointer[Int], x: X) -> Int:
    return fp.match(x,
        lambda (n: SingleNum, c: ArcPointer[Int]) -> Int: count(c, n.value),
        lambda (a: SingleAdd[Int], c: ArcPointer[Int]) -> Int: count(c, a.left + a.right),
        lambda (e: X, c: ArcPointer[Int]) -> Int: 0,
        context=counter)


def count(counter: ArcPointer[Int], value: Int) -> Int:
    counter[] += 1
    return value


def main() raises:
    var two: X = SingleNum(2)
    var three: X = SingleNum(3)
    assert_equal(value_of(X(SingleAdd(two, three))), 5)
    assert_equal(value_of(X(SingleSum([two, three, X(SingleAdd(two, two))]))), 9)
    assert_equal(value_of(X(SingleSum(List[X]()))), 0)
    assert_equal(value_of(X(SingleOpt(Optional[X](three)))), 3)
    assert_equal(value_of(X(SingleOpt(Optional[X](None)))), -1)

    # Next continues with the branch taken; the other is never evaluated.
    var bomb: X = SingleBoom(7)
    assert_equal(value_of(X(SingleIf(two, three, bomb))), 3)
    assert_equal(value_of(X(SingleIf(X(SingleNum(0)), bomb, two))), 2)
    assert_equal(value_of(X(SingleIf(two, bomb, three))), -1007)

    # A chain of Next steps: each continues with a smaller value.
    var chain: X = three
    for _ in range(1000):
        chain = SingleIf(two, chain, bomb)
    assert_equal(value_of(chain), 3)

    assert_equal(describe(X(SingleAdd(X(SingleNum(0)), two))), "zero plus")
    assert_equal(describe(X(SingleAdd(two, two))), "plus")
    assert_equal(describe(three), "number 3")
    assert_equal(describe(X(SingleSum(List[X]()))), "other")

    assert_equal(guarded_sum(X(SingleAdd(X(SingleNum(101)), two))), 100)
    assert_equal(guarded_sum(X(SingleAdd(X(SingleNum(5)), X(SingleAdd(two, three))))), 10)

    assert_equal(scaled(X(SingleAdd(two, three)), 10), 50)

    # A value shared by many parents is evaluated once per match.
    var shared: X = two
    for _ in range(60):
        shared = SingleAdd(shared, shared)
    var calls = ArcPointer(0)
    assert_equal(counted(calls, shared), 2 << 60)
    assert_equal(calls[], 61)

    # Deep values evaluate without native recursion.
    var deep: X = SingleNum(0)
    for _ in range(1_000_000):
        deep = SingleAdd(deep, X(SingleNum(1)))
    assert_equal(value_of(deep), 1_000_000)
