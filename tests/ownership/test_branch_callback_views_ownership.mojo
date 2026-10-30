"""Branch handles retain shared callback origins and clean up only owned state."""
from fp.functions import partial, as_unary
from fp.iteration import iterated, partition, partition_map, Unbounded, BoundedFail
from fp.data import Result, Ok, Err
from fp.callables.products import _take_pair
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer, MaybeUninit
from std.iter import next
from std.os import abort
from std.testing import assert_equal, assert_true


def pulled(var value: Token) -> Token:
    value.trace[].pulls += 1
    return value^

@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def below(var prefix: Prefix, value: Token) -> Bool:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    return value.id < 3


def predicate_owners() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var predicate = partial(below, prefix)
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads), Token(4, payloads)]
    var branches = iterated(values^).map(pulled).partition(predicate, buffer=Unbounded())
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(payloads[].pulls, 0)
    var rejected = next(branches[1])
    assert_equal(rejected.id, 3)
    assert_equal(ledger[].factories, 4)
    assert_equal(ledger[].calls, 3)
    assert_equal(payloads[].pulls, 3)
    assert_equal(ledger[].restarts, 0)
    assert_equal(ledger[].drops[0], 3)
    branches[0].close()
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)
    assert_equal(payloads[].drops[3], 0)
    assert_equal(payloads[].drops[4], 0)
    branches[1].close()
    assert_equal(payloads[].drops[4], 1)
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].drops[0], 3)
    _ = branches^
    _ = rejected^
    var unused: List[Token] = [Token(5, payloads)]
    var abandoned = partition(unused^, predicate, buffer=Unbounded())
    _ = abandoned^
    assert_equal(payloads[].drops[5], 1)
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].factories, 4)
    var empty = partition(List[Token](), predicate^, buffer=Unbounded())
    _ = empty^
    assert_equal(ledger[].drops[0], 4)
    _ = prefix^
    assert_equal(ledger[].drops[0], 5)
    for i in range(1, 6): assert_equal(payloads[].drops[i], 1)


def classifier_owners() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def route(var value: Token) {var state^} -> Result[Token, Token]:
        state.trace[].calls += 1
        if value.id % 2 == 0: return Ok(value^)
        return Err(value^)
    var classifier = as_unary(route^)
    comptime assert not conforms_to(type_of(classifier), Copyable)
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads), Token(4, payloads)]
    var branches = partition_map(iterated(values^).map(pulled), classifier, buffer=Unbounded())
    assert_equal(ledger[].calls, 0)
    var first = MaybeUninit[type_of(branches[0])]()
    var second = MaybeUninit[type_of(branches[1])]()
    _take_pair(branches^, first, second)
    var accepted = first^.unsafe_assume_init()
    _ = second^.unsafe_assume_init()
    var kept = next(accepted)
    assert_equal(kept.id, 2)
    assert_equal(ledger[].calls, 2)
    assert_equal(payloads[].pulls, 2)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 0)
    _ = accepted^
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)
    assert_equal(ledger[].drops[0], 0)
    _ = kept^
    var remaining: List[Token] = [Token(5, payloads), Token(6, payloads)]
    var moved = iterated(remaining^).partition_map(classifier^, buffer=Unbounded())
    var rejected = next(moved[1])
    assert_equal(rejected.id, 5)
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].drops[0], 0)
    _ = moved^
    assert_equal(ledger[].drops[0], 1)
    assert_equal(payloads[].drops[5], 0)
    assert_equal(payloads[].drops[6], 1)
    _ = rejected^
    for i in range(1, 7): assert_equal(payloads[].drops[i], 1)


def capacity() -> BoundedFail:
    try: return BoundedFail(1)
    except: abort("one is a valid capacity")

def overflow() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def reject(var value: Token) {var state^} -> Result[Token, Token]:
        state.trace[].calls += 1
        return Err(value^)
    var classifier = as_unary(reject^)
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads)]
    var branches = partition_map(iterated(values^).map(pulled), classifier, buffer=capacity())
    assert_true(next(branches[0]).is_err())
    assert_true(next(branches[1]).is_err())
    assert_equal(ledger[].calls, 2)
    assert_equal(payloads[].pulls, 2)
    for i in range(1, 4): assert_equal(payloads[].drops[i], 1)
    assert_equal(ledger[].drops[0], 0)
    _ = branches^
    var empty = partition_map(List[Token](), classifier, buffer=Unbounded())
    _ = empty^
    assert_equal(ledger[].calls, 2)
    _ = classifier^
    assert_equal(ledger[].drops[0], 1)


def outside(owner: List[Int]) raises -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    def classify(size: Int, value: View) -> Result[View, Int]:
        if len(value) >= size: return Ok(value)
        return Err(len(value))
    var classifier = partial(classify, 1)
    var values: List[View] = [view]
    var branches = partition_map(values^, classifier, buffer=Unbounded())
    return next(branches[0])


def main() raises:
    predicate_owners()
    classifier_owners()
    overflow()
    var owner: List[Int] = [7, 11]
    var retained = outside(owner)
    assert_true(Pointer(to=retained[1]) == Pointer(to=owner[1]))
