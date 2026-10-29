"""Stateful native capture composes through the ordinary mutable callback path."""
from fp.data import Capture, Result, Ok
from fp.callables import MutableUnary, mut_ref
from fp.functions import pipeline, flow
from fp.iteration import iterated
from std.testing import assert_equal


def debit(mut balance: Int, var amount: Int) raises Int -> Int:
    balance -= amount
    if balance < 0:
        raise balance
    return balance


def add(mut total: Int, var amount: Int) -> Int:
    total += amount
    return total


def add_never(mut total: Int, var amount: Int) raises Never -> Int:
    return add(total, amount)


def notify(mut total: Int, var amount: Int):
    total += amount


def describe(var result: Result[Int, Int]) -> String:
    return "accepted" if result.is_ok() else "declined"


def main() raises:
    var account = Capture[Int]().stateful(debit, 10)
    comptime assert conforms_to(type_of(account), MutableUnary)
    comptime assert type_of(account).Error == Never
    comptime assert type_of(account).Out == Result[Int, Int]
    var mapped = pipeline[Int]([3, 8, -2]).map(mut_ref(account)).get()
    assert_equal(len(mapped), 3)
    assert_equal(mapped[0].copy().get_or(0), 7)
    assert_equal(mapped[1].copy().swap().get_or(0), -1)
    assert_equal(mapped[2].copy().get_or(0), 1)
    assert_equal(account.state(), 1)

    var checked = Capture[Int]().stateful(debit, 10)
    var traversed = pipeline[Int]([3, 8, 100]).traverse(mut_ref(checked)).get()
    comptime assert type_of(traversed) == Result[List[Int], Int]
    assert_equal(traversed^.swap().get_or(0), -1)
    assert_equal(checked.state(), -1)
    var empty = pipeline(List[Int]()).traverse(mut_ref(checked)).get()
    assert_equal(empty.is_ok(), True)
    assert_equal(checked.state(), -1)

    var pending_owner = Capture[Int]().stateful(debit, 10)
    var pending = iterated(range(1, 5)).map(mut_ref(pending_owner)).take(2)
    var first = pending^.to_list()
    assert_equal(len(first), 2)
    assert_equal(first[0].copy().get_or(0), 9)
    assert_equal(first[1].copy().get_or(0), 7)
    assert_equal(pending_owner.state(), 7)
    assert_equal(pending_owner.run(2).get_or(0), 5)

    var pure = Capture[String]().stateful(add, 0)
    comptime assert type_of(pure).Out == Result[Int, Never]
    var total = pipeline[Int]([1, 2, 3]).traverse(mut_ref(pure)).get()
    assert_equal(total^.get_or(List[Int]()), [1, 3, 6])
    assert_equal(pure^.into_state(), 6)
    var never = Capture[Int]().stateful(add_never, 0)
    assert_equal(Result[Int, Never](Ok(3)).flat_map(mut_ref(never)).get_or(0), 3)
    var notification = Capture[Int]().stateful(notify, 0)
    var notified = pipeline(Optional(4)).map(mut_ref(notification)).get()
    comptime assert type_of(notified) == Optional[Result[type_of(None), Never]]
    assert_equal(notified.value().is_ok(), True)
    assert_equal(notification.state(), 4)

    var chain = flow(mut_ref(account), describe)
    assert_equal(pipeline[Int]([2, -3]).map(chain^).get(), ["declined", "accepted"])
    assert_equal(account.state(), 2)
    var transferred = Capture[Int]().stateful(debit, 10)
    var owned_results = iterated(range(1, 3)).map(transferred^).to_list()
    assert_equal(owned_results[1].copy().get_or(0), 7)

    # Native origin tracking permits sequential state updates before lazy pulls.
    var interleaved = Capture[Int]().stateful(add, 0)
    var scheduled = iterated(range(1, 3)).map(mut_ref(interleaved))
    assert_equal(interleaved.run(10).get_or(0), 10)
    var later = scheduled^.to_list()
    assert_equal(later[0].copy().get_or(0), 11)
    assert_equal(later[1].copy().get_or(0), 13)
    assert_equal(interleaved.state(), 13)
