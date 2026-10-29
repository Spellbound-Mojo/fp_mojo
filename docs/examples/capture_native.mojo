"""Bind argument ownership before selecting a native callback."""
from fp.data import Capture, Result
from std.testing import assert_equal

@fieldwise_init
struct CaptureDeclined(Movable):
    var balance: Int

def debit(mut balance: Int, var payment: Int, /, var **fees: Int) raises CaptureDeclined -> Int:
    balance -= payment
    for fee in fees.values(): balance -= fee
    if balance < 0: raise CaptureDeclined(balance)
    return balance

def count(mut total: Int, var text: String) -> Int:
    total += text.byte_length()
    return total

def main() raises:
    var balance = 10
    var paid = Capture[CaptureDeclined].mutable(balance).take(6).kwargs(fee=1).run(debit)
    comptime assert type_of(paid) == Result[Int, CaptureDeclined]
    assert_equal(paid^.to_optional().value(), 3)
    var declined = Capture[CaptureDeclined].mutable(balance).take(5).kwargs[K=Int]().run(debit)
    assert_equal(declined^.swap().to_optional().value().balance, -2)
    assert_equal(balance, -2)
    print("payment: 3; declined: -2; balance:", balance)

    # Explicit owned state survives repeated calls without a callable struct.
    var counter = Capture().stateful(count, 0)
    assert_equal(counter.run(String("abc")).raise_on_err(), 3)
    assert_equal(counter.run(String("de")).raise_on_err(), 5)
    print("count:", counter^.into_state())
