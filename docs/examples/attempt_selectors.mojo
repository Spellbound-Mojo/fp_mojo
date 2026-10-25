"""Select native argument conventions while capturing their exact outcomes."""
from fp.data import Result, attempt, attempt_kwargs, raise_on_err
from std.testing import assert_equal

def length(var text: String) -> Int:
    return text.byte_length()

def deposit(var amount: Int, mut balance: Int) -> Int:
    balance += amount
    return balance

def debit(mut balance: Int, /, var **charges: Int) raises String:
    for charge in charges.values():
        balance -= charge
    if balance < 0:
        raise String("overdrawn")

def main() raises:
    var text = String("Mojo")
    var size = attempt[owned=True](length, text^)
    comptime assert type_of(size) == Result[Int, Never]
    assert_equal(raise_on_err(size^), 4)
    print("length: 4")

    var balance = 10
    var deposited = attempt[owned_mut=True](deposit, 3, balance)
    assert_equal(raise_on_err(deposited^), 13)
    assert_equal(balance, 13)
    print("balance:", balance)

    var failed = attempt_kwargs[mutable=True](debit, balance, payment=20, fee=1)
    comptime assert type_of(failed) == Result[type_of(None), String]
    assert_equal(failed.is_err(), True)
    assert_equal(balance, -8)
    print("failed:", failed.is_err(), "; balance:", balance)
