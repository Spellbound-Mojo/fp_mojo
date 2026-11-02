"""Describe an order program with IO, then run it and read its outcome."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, run
from fp.functions import pipeline
from std.testing import assert_equal


def read_quantity() -> Int:
    print("read quantity")
    return 3


def subtotal(quantity: Int) -> Int:
    print("price", quantity, "items")
    return quantity * 12


def add_shipping(amount: Int) -> IO[Int, String]:
    print("add shipping to", amount)
    return IO[Int, String].pure(amount + 5)


def order() -> IO[Int, String]:
    print("build order")
    return pipeline(IO[Int, String].delay(read_quantity)).map(subtotal).flat_map(add_shipping).get()


def total(value: Int) -> Int:
    return value


def failed(var failure: EffectFailure[String]) -> Int:
    print("failed:", failure.errors.first())
    return -1


def canceled() -> Int:
    print("canceled")
    return -2


def main() raises:
    var built = order()
    print("built")
    var deferred = IO[Int, String].defer(order)
    print("deferred")

    var first = fold_outcome(run(built^), total, failed, canceled)
    assert_equal(first, 41)
    print("total:", first)
    var second = fold_outcome(run(deferred^), total, failed, canceled)
    assert_equal(second, 41)
    print("total:", second)
