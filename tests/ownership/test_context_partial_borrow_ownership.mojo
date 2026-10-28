"""Borrowed payloads are never copied; shared admission retains the stored prefix."""
from fp.functions import pipeline, partial
from fp.effects import Reader, run
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.data import ok

@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def odd(var prefix: Prefix, value: Token) -> Bool:
    prefix.ledger[].calls += 1
    return value.id % 2 == 1

def copies() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var predicate = partial(odd, prefix)
    assert_equal(ledger[].factories, 1)
    var selected = pipeline[Token]([Token(1, payloads), Token(2, payloads)]).filter(predicate).get()
    assert_equal(ledger[].factories, 3)
    assert_equal(ledger[].drops[0], 2)
    assert_equal(payloads[].drops[1], 0)
    assert_equal(payloads[].drops[2], 1)
    _ = selected^
    assert_equal(payloads[].drops[1], 1)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(Token(3, payloads))).tap_each(predicate).get()
    assert_equal(ledger[].calls, 2)
    var result = run[Reader[Int]](pending^, 0)
    assert_equal(result.id, 3)
    _ = result^
    var abandoned = pipeline[Reader[Int]](Reader[Int].pure(Token(4, payloads))).tap_each(predicate).get()
    _ = abandoned^
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].factories, 4)
    var owned = pipeline[Reader[Int]](Reader[Int].pure(Token(5, payloads))).tap_each(predicate^).get()
    _ = run[Reader[Int]](owned^, 0)
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].factories, 5)
    assert_equal(ledger[].drops[0], 5)
    _ = prefix^
    assert_equal(ledger[].drops[0], 6)
    for i in range(1, 6): assert_equal(payloads[].drops[i], 1)


def outside(owner: List[Int]) raises -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var prefix: View, value: Int) -> View: return prefix
    var callback = partial(keep, view)
    var projected = pipeline(Optional(1)).pair_with(callback).get()
    assert_true(Pointer(to=projected.value()[1][0]) == Pointer(to=owner[0]))
    return pipeline(ok[Int](2)).fold(callback, callback)


def main() raises:
    copies()
    var owner: List[Int] = [7, 11]
    var view = outside(owner)
    assert_true(Pointer(to=view[1]) == Pointer(to=owner[1]))
