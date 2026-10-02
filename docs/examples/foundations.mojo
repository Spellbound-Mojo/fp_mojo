"""Native callbacks, terminal folds, typed errors, and a value stored in place."""

import fp
from std.testing import assert_equal, assert_false
from fp.adt import Data, Cases, Choice, Value
from fp.iteration import fold_left
from fp.data import attempt, raise_on_err


@fieldwise_init
struct Empty(Copyable):
    pass


@fieldwise_init
struct Number(Copyable):
    var value: Int


@fieldwise_init
struct Pair(Copyable):
    var left: Int
    var right: Int


struct Term(Data):
    comptime Layer[R: Value] = Cases[Empty, Number, Pair]


@fieldwise_init
struct InvalidCount(Copyable, Writable):
    var count: Int


def main() raises:
    var calls = 0
    def add(var total: Int, var item: Int) {mut calls} -> Int:
        calls += 1
        return total + item
    var total = fold_left(add, 0, range(1, 6))
    assert_equal(total, 15)
    assert_equal(calls, 5)

    var value: Choice[Term] = Pair(total, 7)
    var answer = fp.match(value,
        lambda (e: Empty) -> Int: 0,
        lambda (n: Number) -> Int: n.value,
        lambda (p: Pair) -> Int: p.left + p.right)
    assert_equal(answer, 22)

    def checked() raises InvalidCount {var answer} -> Int:
        if answer < 0:
            raise InvalidCount(answer)
        return answer
    var result = attempt(checked)
    var restored = 0
    var failed = False
    try:
        restored = raise_on_err(result^)
    except error:
        failed = True
    assert_false(failed)
    assert_equal(restored, 22)
    print("fold =", total, "; match =", answer, "; callbacks =", calls)
