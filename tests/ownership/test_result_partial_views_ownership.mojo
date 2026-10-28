"""Shared partial observers retain prefixes and borrow move-only stored errors."""
from fp.functions import partial, piped
from fp.data import ok, err
from fp.effects import ReaderT, run
from fp.algebra import ResultFamily
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def odd(var prefix: Prefix, value: Token) -> Bool:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    return value.id % 2 == 1

def make_error(var prefix: Prefix, value: Token) -> Int:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    return value.id

def copies() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var predicate = partial(odd, prefix)
    var error = partial(make_error, prefix)
    assert_equal(ledger[].factories, 2)
    var success = ok[Int](Token(1, payloads)).ensure(predicate, error)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].factories, 3)
    assert_equal(payloads[].drops[1], 0)
    _ = success^
    var failure = ok[Int](Token(2, payloads)).ensure(predicate, error)
    assert_equal(failure^.swap().get_or(0), 2)
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].factories, 5)
    assert_equal(payloads[].drops[2], 1)
    var observed = err[String](Token(3, payloads)).tap_err(predicate)
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].factories, 6)
    assert_equal(payloads[].drops[3], 0)
    _ = observed^
    comptime I = ReaderT[ResultFamily[Token], Int]
    var skipped = piped(I.pure(String("kept"))).tap_err[I](predicate).get()
    assert_equal(run[I](skipped^, 0).get_or(""), "kept")
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].factories, 6)
    var pending = piped(I.lift(err[String](Token(4, payloads)))).tap_err[I](predicate).get()
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].factories, 6)
    var result = run[I](pending^, 0)
    assert_equal(ledger[].calls, 5)
    assert_equal(ledger[].factories, 7)
    assert_equal(payloads[].drops[4], 0)
    _ = result^
    var abandoned = piped(I.lift(err[String](Token(5, payloads)))).tap_err[I](predicate).get()
    _ = abandoned^
    assert_equal(ledger[].calls, 5)
    assert_equal(ledger[].factories, 7)
    var moved = piped(I.lift(err[String](Token(6, payloads)))).tap_err[I](predicate^).get()
    _ = run[I](moved^, 0)
    assert_equal(ledger[].calls, 6)
    assert_equal(ledger[].factories, 8)
    assert_equal(ledger[].drops[0], 7)
    assert_equal(ledger[].restarts, 0)
    _ = error^
    _ = prefix^
    assert_equal(ledger[].drops[0], 9)
    for i in range(1, 7): assert_equal(payloads[].drops[i], 1)


def reject(var prefix: Prefix, value: Token) raises Token -> Int:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    raise Token(7, prefix.ledger)


def errors() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var observer = partial(reject, prefix)
    comptime I = ReaderT[ResultFamily[Token], Int]
    var pending = piped(I.lift(err[String](Token(1, payloads)))).tap_err[I](observer).get()
    var caught = False
    try: _ = run[I](pending^, 0)
    except error:
        comptime assert type_of(error) == Token
        assert_equal(error.id, 7)
        assert_equal(payloads[].drops[1], 1)
        assert_equal(ledger[].drops[7], 0)
        _ = error^
        caught = True
    assert_true(caught)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].restarts, 0)
    assert_equal(ledger[].factories, 2)
    assert_equal(ledger[].drops[0], 1)
    _ = observer^
    _ = prefix^
    assert_equal(ledger[].drops[0], 3)
    assert_equal(ledger[].drops[7], 1)


def outside(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var prefix: View, value: Int) -> View: return prefix
    var callback = partial(keep, view)
    return ok[Int](1).fold(callback, callback)


def main() raises:
    copies()
    errors()
    var owner: List[Int] = [7, 11]
    var result = outside(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
