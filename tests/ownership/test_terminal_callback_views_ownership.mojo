"""Shared projections keep exact capture, payload, stopping and origin behavior."""
from fp.functions import partial, piped, pipeline, as_unary
from fp.iteration import iterated, sum_by, max_by, find_map
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.iter import Iterator
from std.testing import assert_equal, assert_true


def captures() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def project(var value: Token) {var state^} -> Int:
        state.trace[].calls += 1
        return value.id
    var callback = as_unary(project^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    var one: List[Token] = [Token(1, payloads)]
    assert_equal(sum_by(callback, one^), 1)
    var two: List[Token] = [Token(2, payloads)]
    assert_equal(iterated(two^).sum_by(callback), 2)
    var three: List[Token] = [Token(3, payloads)]
    assert_equal(piped(three^).sum_by(callback).get(), 3)
    var four: List[Token] = [Token(4, payloads)]
    assert_equal(pipeline(four^).sum_by(callback).get(), 4)
    assert_equal(sum_by(callback, List[Token]()), 0)
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].drops[0], 0)
    var five: List[Token] = [Token(5, payloads)]
    assert_equal(sum_by(callback^, five^), 5)
    assert_equal(ledger[].calls, 5)
    assert_equal(ledger[].drops[0], 1)
    for i in range(1, 6): assert_equal(payloads[].drops[i], 1)


@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def key(var prefix: Prefix, value: Token) -> Int:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    return value.id // 2

def borrowed_keys() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var rank = partial(key, prefix)
    assert_true(not piped(List[Token]()).max_by(rank).get())
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    var first: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads)]
    var maximum = max_by(rank, first^)
    assert_equal(maximum.value().id, 2)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 0)
    assert_equal(payloads[].drops[3], 1)
    _ = maximum^
    var second: List[Token] = [Token(4, payloads), Token(5, payloads), Token(6, payloads)]
    var minimum = iterated(second^).min_by(rank)
    assert_equal(minimum.value().id, 4)
    assert_equal(payloads[].drops[4], 0)
    assert_equal(payloads[].drops[5], 1)
    assert_equal(payloads[].drops[6], 1)
    assert_equal(ledger[].calls, 6)
    assert_equal(ledger[].factories, 7)
    assert_equal(ledger[].drops[0], 6)
    assert_equal(ledger[].restarts, 0)
    _ = minimum^
    _ = rank^
    _ = prefix^
    assert_equal(ledger[].drops[0], 8)
    for i in range(1, 7): assert_equal(payloads[].drops[i], 1)


@fieldwise_init
struct Source(Iterator):
    comptime Element = Token
    var remaining: List[Token]
    var ledger: ArcPointer[Trace]
    def __next__(mut self) raises StopIteration -> Token:
        self.ledger[].pulls += 1
        if not self.remaining: raise StopIteration()
        return self.remaining.pop()

def stopping() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def choose(var value: Token) {var state^} -> Optional[Token]:
        state.trace[].calls += 1
        if value.id == 2: return Optional(value^)
        return None
    var callback = as_unary(choose^)
    var values: List[Token] = [Token(4, payloads), Token(3, payloads), Token(2, payloads), Token(1, payloads)]
    var selected = find_map(callback, Source(values^, ledger))
    assert_equal(selected.value().id, 2)
    assert_equal(ledger[].pulls, 2)
    assert_equal(ledger[].calls, 2)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 0)
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)
    _ = selected^
    assert_true(not iterated(List[Token]()).find_map(callback))
    assert_equal(ledger[].calls, 2)
    assert_equal(ledger[].drops[0], 0)
    _ = callback^
    assert_equal(ledger[].drops[0], 1)
    assert_equal(payloads[].drops[2], 1)


def errors() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def fail(var value: Token) raises Token {var state^} -> Int:
        state.trace[].calls += 1
        raise Token(value.id, state.trace)
    var callback = as_unary(fail^)
    var values: List[Token] = [Token(3, payloads), Token(2, payloads), Token(1, payloads)]
    var caught = False
    try: _ = iterated(Source(values^, ledger)).sum_by(callback)
    except error:
        comptime assert type_of(error) == Token
        assert_equal(error.id, 1)
        caught = True
    assert_true(caught)
    assert_equal(ledger[].pulls, 1)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].drops[1], 1)
    assert_equal(ledger[].drops[0], 0)
    var empty = -1
    try: empty = piped(List[Token]()).sum_by(callback).get()
    except error: _ = error^
    assert_equal(empty, 0)
    _ = callback^
    assert_equal(ledger[].drops[0], 1)
    for i in range(1, 4): assert_equal(payloads[].drops[i], 1)


def outside(owner: List[Int]) -> Optional[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(size: Int, value: View) -> Optional[View]:
        if len(value) >= size: return Optional(value)
        return None
    var choose = partial(keep, 1)
    var values: List[View] = [view]
    return piped(values^).find_map(choose).get()


def main() raises:
    captures()
    borrowed_keys()
    stopping()
    errors()
    var owner: List[Int] = [7, 11]
    var retained = outside(owner)
    assert_true(Pointer(to=retained.value()[1]) == Pointer(to=owner[1]))
