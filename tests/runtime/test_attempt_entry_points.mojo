"""Separate native call shapes retain inferred results, errors and empty packs."""
from fp.data import Capture, Result, raise_on_err
from std.collections import StringDict
from std.testing import assert_equal


@fieldwise_init
struct Failure(Movable):
    var code: Int


def ordinary() raises Failure -> Int:
    raise Failure(7)


def capture[K: Movable & Deinitable, R: Movable & Deinitable,
            E: Movable & Deinitable, //,
            F: def(var **kwargs: K) raises E -> R](
    function: F, /, var **values: K
) -> Result[R, E]:
    return Capture[E].kwargs(**values^).run(function)


def main() raises:
    var result = Capture().run(ordinary)
    comptime assert type_of(result) == Result[Int, Failure]
    var code = 0
    try:
        _ = raise_on_err(result^)
    except error:
        code = error.code
    assert_equal(code, 7)

    var calls = 0
    def total(var **values: Int) raises Failure {mut calls} -> Int:
        calls += 1
        var sum = 0
        for entry in values.items():
            sum += entry.value
        if sum < 0:
            raise Failure(sum)
        return sum

    # Empty packs must select the keyword entry even with no keyword operands.
    var empty = Capture[Failure].kwargs[K=Int]().run(total)
    comptime assert type_of(empty) == Result[Int, Failure]
    var value: Int
    try:
        value = raise_on_err(empty^)
    except error:
        raise Error("unexpected keyword failure")
    assert_equal(value, 0)

    # Names used by the bridge itself remain available as callback keywords.
    var named = Capture[Failure].kwargs(function=2, first=3, values=5).run(total)
    try:
        value = raise_on_err(named^)
    except error:
        raise Error("unexpected keyword failure")
    assert_equal(value, 10)

    var options = StringDict[Int]()
    options["debit"] = -11
    var failed = capture(total, **options^)
    comptime assert type_of(failed) == Result[Int, Failure]
    try:
        _ = raise_on_err(failed^)
    except error:
        code = error.code
    assert_equal(code, -11)
    assert_equal(calls, 3)

    def pure(var **values: Int) -> Int:
        return len(values)
    var success = Capture.kwargs[K=Int]().run(pure)
    comptime assert type_of(success) == Result[Int, Never]
    assert_equal(raise_on_err(success^), 0)
