"""Lazy predicate views retain captures and preserve move-only element lifetimes."""
from fp.functions import partial
from fp.iteration import iterated
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Prefix(Copyable):
    var limit: Int
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.limit = copy.limit
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def below(var prefix: Prefix, value: Token) -> Bool:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    return value.id < prefix.limit

def copies() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(3, ledger)
    var predicate = partial(below, prefix)
    var source: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads), Token(4, payloads)]
    var pending = iterated(source^).take_while(predicate)
    assert_equal(ledger[].calls, 0)
    assert_equal(ledger[].factories, 1)
    var kept = pending^.collect_list()
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].factories, 4)
    assert_equal(ledger[].drops[0], 3)
    assert_equal(payloads[].drops[1], 0)
    assert_equal(payloads[].drops[2], 0)
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)
    _ = kept^
    var inverted: List[Token] = [Token(5, payloads), Token(6, payloads)]
    var retained = iterated(inverted^).filter_not(predicate).collect_list()
    assert_equal(ledger[].calls, 5)
    assert_equal(ledger[].factories, 6)
    assert_equal(payloads[].drops[5], 0)
    assert_equal(payloads[].drops[6], 0)
    _ = retained^
    var unused: List[Token] = [Token(7, payloads)]
    var abandoned = iterated(unused^).filter(predicate)
    _ = abandoned^
    assert_equal(ledger[].calls, 5)
    assert_equal(ledger[].factories, 6)
    assert_equal(payloads[].drops[7], 1)
    var last: List[Token] = [Token(0, payloads)]
    var moved = iterated(last^).filter(predicate^)
    var result = moved^.collect_list()
    assert_equal(ledger[].calls, 6)
    assert_equal(ledger[].factories, 7)
    assert_equal(ledger[].drops[0], 7)
    assert_equal(payloads[].drops[0], 0)
    _ = result^
    var temporary = iterated(List[Token]()).filter(partial(below, prefix))
    assert_equal(ledger[].drops[0], 7)
    _ = temporary^
    assert_equal(ledger[].drops[0], 8)
    assert_equal(ledger[].factories, 8)
    assert_equal(ledger[].restarts, 0)
    _ = prefix^
    assert_equal(ledger[].drops[0], 9)
    for i in range(8): assert_equal(payloads[].drops[i], 1)


def drop_prefix() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(3, ledger)
    var predicate = partial(below, prefix)
    var source: List[Token] = [Token(1, payloads), Token(2, payloads), Token(4, payloads), Token(5, payloads)]
    var pending = iterated(source^).drop_while(predicate)
    assert_equal(ledger[].calls, 0)
    var kept = pending^.collect_list()
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].factories, 4)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)
    assert_equal(payloads[].drops[4], 0)
    assert_equal(payloads[].drops[5], 0)
    _ = kept^
    _ = predicate^
    _ = prefix^
    assert_equal(ledger[].drops[0], 5)
    assert_equal(ledger[].restarts, 0)
    assert_equal(payloads[].drops[4], 1)
    assert_equal(payloads[].drops[5], 1)


def outside(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(size: Int, value: View) -> Bool: return len(value) >= size
    var predicate = partial(keep, 1)
    var inputs: List[View] = [view]
    return iterated(inputs^).filter(predicate).collect_list()


def main() raises:
    copies()
    drop_prefix()
    var owner: List[Int] = [7, 11]
    var values = outside(owner)
    assert_true(Pointer(to=values[0][1]) == Pointer(to=owner[1]))
