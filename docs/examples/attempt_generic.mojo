"""A generic transaction helper preserves state and returns the exact error."""
from fp.data import Capture, Result, raise_on_err
from std.testing import assert_equal

def transaction[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                X: Movable & Deinitable, //,
                F: def(mut A, var B, /, var **kwargs: Int) raises X -> R](
    function: F, mut state: A, var payment: B, /, var **options: Int
) -> Result[R, X]:
    return Capture[X].mutable(state).take(payment^).kwargs(**options^).run(function)

def submit[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
           X: Movable & Deinitable, //,
           F: def(mut A, var B, /, var **kwargs: Int) raises X -> R](
    function: F, mut state: A, var payment: B, /, var **options: Int
) -> Result[R, X]:
    return transaction(function, state, payment^, **options^)

@fieldwise_init
struct Declined(Movable):
    var balance: Int

def main() raises:
    var calls = 0
    def debit(mut balance: Int, var payment: Int, /, var **charges: Int) raises Declined {mut calls} -> String:
        calls += 1
        balance -= payment
        for entry in charges.items(): balance -= entry.value
        if balance < 0: raise Declined(balance)
        return String(balance)
    var balance = 10
    var approved: Result[String, Declined] = submit(debit, balance, 6, fee=1)
    var receipt: String
    try: receipt = raise_on_err(approved^)
    except error: raise Error("unexpected decline")
    assert_equal(receipt, "3")
    var declined: Result[String, Declined] = submit(debit, balance, 5)
    var failure_balance = 0
    try: _ = raise_on_err(declined^)
    except error: failure_balance = error.balance
    assert_equal(failure_balance, -2)
    assert_equal(balance, -2)
    assert_equal(calls, 2)
    print("generic attempt: receipt=3; declined=-2; balance=-2; calls=2")
