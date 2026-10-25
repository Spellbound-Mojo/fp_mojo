"""Borrow a callback with its argument convention before capturing its outcome."""
from fp.data import (
    Result, attempt, attempt_kwargs, raise_on_err,
    mutating, consuming, mut_owned, mut_owned_kwargs,
)
from std.testing import assert_equal

def increment(mut value: Int) -> Int:
    value += 1
    return value

def length(var text: String) -> Int:
    return text.byte_length()

def deposit(mut balance: Int, var amount: Int) -> Int:
    balance += amount
    return balance

def debit(mut balance: Int, var amount: Int, /, var **fees: Int) raises String -> Int:
    balance -= amount
    for entry in fees.items():
        balance -= entry.value
    if balance < 0:
        raise String("overdrawn")
    return balance

def main() raises:
    var balance = 10
    var updated = attempt(mutating(increment), balance)
    comptime assert type_of(updated) == Result[Int, Never]
    assert_equal(raise_on_err(updated^), 11)
    print("updated:", balance)

    var text = String("Mojo")
    var consumed = attempt(consuming(length), text^)
    assert_equal(raise_on_err(consumed^), 4)
    print("consumed: 4")

    var add = mut_owned(deposit)
    var deposited = attempt(add, balance, 3)
    assert_equal(raise_on_err(deposited^), 14)
    print("mixed:", balance)

    var failed = attempt_kwargs(mut_owned_kwargs(debit), balance, 20, fee=1)
    comptime assert type_of(failed) == Result[Int, String]
    assert_equal(failed.is_err(), True)
    assert_equal(balance, -7)
    print("failed:", failed.is_err(), "; balance:", balance)
