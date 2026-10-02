"""Clause errors: Error and typed errors propagate unchanged and stop the match."""
import fp
from fp.adt import Data, Cases, Node, Value
from std.testing import assert_equal


@fieldwise_init
struct ErrorsNum(Copyable):
    var value: Int


@fieldwise_init
struct ErrorsDiv[R: Value](Movable):
    var left: Self.R
    var right: Self.R


struct ErrorsExpr(Data):
    comptime Layer[R: Value] = Cases[ErrorsNum, ErrorsDiv[R]]


comptime D = Node[ErrorsExpr]


@fieldwise_init
struct ErrorsDivByZero(Movable):
    var numerator: Int


def number(n: ErrorsNum) -> Int:
    return n.value


def divide(d: ErrorsDiv[Int]) raises ErrorsDivByZero -> Int:
    if d.right == 0:
        raise ErrorsDivByZero(d.left)
    return d.left // d.right


def divide_error(d: ErrorsDiv[Int]) raises -> Int:
    if d.right == 0:
        raise Error("division by zero")
    return d.left // d.right


def nonzero(d: ErrorsDiv[Int]) raises ErrorsDivByZero -> Bool:
    if d.right == 0:
        raise ErrorsDivByZero(-d.left)
    return d.right > 1


def typed(x: D) -> Int:
    try:
        return fp.match(x, number, divide)
    except error:
        return -1000 - error.numerator


def guarded(x: D) -> Int:
    """A raising guard, then a pure clause for the same constructor."""
    try:
        return fp.match(x, number, fp.when[nonzero, divide], lambda (d: ErrorsDiv[Int]) -> Int: d.left)
    except error:
        return -1000 - error.numerator


def main() raises:
    var four: D = ErrorsNum(4)
    var two: D = ErrorsNum(2)
    var zero: D = ErrorsNum(0)
    assert_equal(typed(D(ErrorsDiv(four, two))), 2)
    assert_equal(typed(D(ErrorsDiv(four, zero))), -1004)
    # The failing division is inside; the outer division never runs.
    assert_equal(typed(D(ErrorsDiv(D(ErrorsDiv(four, zero)), two))), -1004)

    assert_equal(fp.match(D(ErrorsDiv(four, two)), number, divide_error), 2)
    var message = String()
    try:
        _ = fp.match(D(ErrorsDiv(two, zero)), number, divide_error)
    except error:
        message = String(error)
    assert_equal(message, "division by zero")

    assert_equal(guarded(D(ErrorsDiv(four, two))), 2)
    assert_equal(guarded(D(ErrorsDiv(four, D(ErrorsNum(1))))), 4)
    assert_equal(guarded(D(ErrorsDiv(four, zero))), -996)
