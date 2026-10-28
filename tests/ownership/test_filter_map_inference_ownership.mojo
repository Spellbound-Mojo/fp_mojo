"""Inferred Optional payloads preserve lazy callback and element ownership."""
from fp.functions import partial, as_unary
from fp.iteration import iterated, filter_map
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true


def pulled(var value: Token) -> Token:
    value.trace[].pulls += 1
    return value^


def native_capture() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def select(var value: Token) {var state^} -> Optional[Token]:
        state.trace[].calls += 1
        if value.id % 2 == 0: return Optional(value^)
        return None
    var callback = as_unary(select^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads), Token(4, payloads)]
    var pending = filter_map(callback, iterated(values^).map(pulled))
    assert_equal(ledger[].calls, 0)
    assert_equal(payloads[].pulls, 0)
    var retained = next(pending)
    assert_equal(retained.id, 2)
    assert_equal(ledger[].calls, 2)
    assert_equal(payloads[].pulls, 2)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 0)
    _ = pending^
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)
    assert_equal(ledger[].drops[0], 0)
    var empty = iterated(List[Token]()).filter_map(callback)
    assert_equal(len(empty^.collect_list()), 0)
    assert_equal(ledger[].calls, 2)
    assert_equal(ledger[].drops[0], 0)
    var last: List[Token] = [Token(5, payloads), Token(6, payloads)]
    var moved = iterated(last^).filter_map(callback^)
    var kept = moved^.collect_list()
    comptime assert type_of(kept) == List[Token]
    assert_equal(kept[0].id, 6)
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].drops[0], 1)
    assert_equal(payloads[].drops[5], 1)
    assert_equal(payloads[].drops[6], 0)
    _ = kept^
    _ = retained^
    for i in range(1, 7): assert_equal(payloads[].drops[i], 1)


@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def selected(var prefix: Prefix, value: Token) -> Optional[Int]:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    if value.id % 2 == 0: return Optional(value.id)
    return None

def partial_capture() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var callback = partial(selected, prefix)
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads)]
    var pending = iterated(values^).filter_map(callback)
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(next(pending), 2)
    assert_equal(ledger[].calls, 2)
    assert_equal(ledger[].factories, 3)
    assert_equal(ledger[].restarts, 0)
    assert_equal(ledger[].drops[0], 2)
    _ = pending^
    assert_equal(payloads[].drops[3], 1)
    var empty = filter_map[U=Int](callback^, List[Token]())
    _ = empty^
    assert_equal(ledger[].drops[0], 3)
    _ = prefix^
    assert_equal(ledger[].drops[0], 4)
    for i in range(1, 4): assert_equal(payloads[].drops[i], 1)


def outside(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(size: Int, value: View) -> Optional[View]:
        if len(value) >= size: return Optional(value)
        return None
    var project = partial(keep, 1)
    var values: List[View] = [view]
    return iterated(values^).filter_map(project).collect_list()


def captured_output(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var value: Int) {view} -> Optional[View]:
        if value == 0: return Optional(view)
        return None
    var project = as_unary(keep)
    return iterated(range(2)).filter_map(project).collect_list()


def main() raises:
    native_capture()
    partial_capture()
    var owner: List[Int] = [7, 11]
    var retained = outside(owner)
    assert_true(Pointer(to=retained[0][1]) == Pointer(to=owner[1]))
    var captured = captured_output(owner)
    assert_true(Pointer(to=captured[0][0]) == Pointer(to=owner[0]))
