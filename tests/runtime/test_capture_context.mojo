"""A reusable context selects errors uniformly before every admission shape."""
from fp.data import Capture, Result
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Item(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def extract(var item: Item) -> Int: return item.value
def pure() -> Int: return 7
def explicit_never() raises Never -> String: return "ready"
def fail() raises Int -> Int: raise 9
def length(value: String) -> Int: return value.byte_length()
def sum_keywords(var **values: Int) -> Int:
    var total = 0
    for value in values.values(): total += value
    return total

def debit(mut balance: Int, var amount: Int) raises Int -> Int:
    balance -= amount
    if balance < 0: raise balance
    return balance

def main() raises:
    var capture = Capture[Int]()
    var copied = capture
    var ready = copied.run(explicit_never)
    comptime assert type_of(ready) == Result[String, Never]
    assert_equal(ready._ok().value, "ready")
    var ok = capture.run(pure)
    comptime assert type_of(ok) == Result[Int, Never]
    assert_equal(ok._ok().value, 7)
    var error = capture.run(fail)
    comptime assert type_of(error) == Result[Int, Int]
    assert_equal(error._err().value, 9)
    var name = String("owner")
    assert_equal(capture.borrow(name).run(length)._ok().value, 5)
    assert_equal(capture.args(name.copy()).run(length)._ok().value, 5)
    assert_equal(capture.kwargs(a=2, b=3).run(sum_keywords)._ok().value, 5)
    assert_equal(capture.kwargs[K=Int]().run(sum_keywords)._ok().value, 0)
    var balance = 6
    assert_equal(capture.mutable(balance).take(2).run(debit)._ok().value, 4)
    assert_equal(capture.mutable(balance).take(7).run(debit)._err().value, -3)
    assert_equal(balance, -3)
    var repeated = capture.stateful(debit, 10)
    assert_equal(repeated.run(4)._ok().value, 6)
    assert_equal(repeated.run(8)._err().value, -2)
    assert_equal(repeated^.into_state(), -2)
    var drops = ArcPointer(0)
    assert_equal(capture.take(Item(11, drops)).run(extract)._ok().value, 11)
    assert_equal(drops[], 1)
    discard(capture, drops)
    assert_equal(drops[], 2)

def discard(capture: Capture[Int], drops: ArcPointer[Int]):
    var pending = capture.args(Item(12, drops))
    _ = pending^
