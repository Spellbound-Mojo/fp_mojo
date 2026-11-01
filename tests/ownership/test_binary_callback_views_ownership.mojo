"""Shared binary views retain captures, source order and independent output origins."""
from fp.functions import partial, flow, flip, as_unary
from fp.iteration import iterated, zip_with
from fp.callables import Binary
from algebra_support.result_ownership import Token, Trace, trace
from algebra_support.alignment import I4Source, i4_done
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true

def add(bias: Int, a: Int, b: Int) -> Int: return bias + a + b

def composition_lifetime() raises:
    var ledger = trace()
    var state = Token(0, ledger)
    def offset(var value: Int) {var state^} -> Int:
        state.trace[].calls += 1
        return value + 10
    var callback = flow(partial(add, 0), as_unary(offset^))
    comptime assert not conforms_to(type_of(callback), Copyable)
    var pulls = ArcPointer(List[Int]())
    var drops = ArcPointer(0)
    var pending = zip_with(I4Source(0,3,1,pulls,drops), I4Source(0,1,2,pulls,drops), callback)
    assert_equal(len(pulls[]), 0)
    assert_equal(ledger[].calls, 0)
    assert_equal(next(pending), 10)
    i4_done(pending)
    assert_equal(pulls[], [100,200,101,201])
    assert_equal(ledger[].calls, 1)
    _ = pending^
    assert_equal(drops[], 2)
    assert_equal(ledger[].drops[0], 0)
    assert_equal(iterated(range(2)).map_with_index(callback, start=5).collect_list(), [15,17])
    assert_equal(ledger[].calls, 3)
    var moved = iterated(range(3)).zip_with(range(3), callback^)
    assert_equal(next(moved), 10)
    _ = moved^
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].drops[0], 1)


@fieldwise_init
struct KeepFirst(Binary):
    comptime First = Token
    comptime Second = Token
    comptime Out = Token
    var state: Token
    def call(self, var first: Token, var second: Token) -> Token:
        self.state.trace[].calls += 1
        _ = second^
        return first^

def flipped_payloads() raises:
    var captures = trace()
    var payloads = trace()
    var callback = flip(KeepFirst(Token(0, captures)))
    comptime assert not conforms_to(type_of(callback), Copyable)
    var left: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads)]
    var right: List[Token] = [Token(4, payloads)]
    var pending = iterated(left^).zip_with(right^, callback)
    assert_equal(captures[].calls, 0)
    var retained = next(pending)
    assert_equal(retained.id, 4)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[4], 0)
    i4_done(pending)
    assert_equal(payloads[].drops[2], 1)
    assert_equal(captures[].calls, 1)
    _ = pending^
    assert_equal(payloads[].drops[3], 1)
    assert_equal(captures[].drops[0], 0)
    var empty = zip_with(List[Token](), List[Token](), callback^)
    _ = empty^
    assert_equal(captures[].calls, 1)
    assert_equal(captures[].drops[0], 1)
    _ = retained^
    for i in range(1,5): assert_equal(payloads[].drops[i], 1)


@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def selected(var prefix: Prefix, first: Token, second: Token) -> Int:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += first.trace[].drops[first.id] + second.trace[].drops[second.id]
    return first.id + second.id

def partial_copies() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var callback = partial(selected, prefix)
    var left: List[Token] = [Token(1, payloads), Token(2, payloads)]
    var right: List[Token] = [Token(3, payloads), Token(4, payloads)]
    var pending = iterated(left^).zip_with(right^, callback)
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(next(pending), 4)
    assert_equal(ledger[].factories, 2)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].restarts, 0)
    _ = pending^
    assert_equal(ledger[].drops[0], 1)
    var empty = zip_with(List[Token](), List[Token](), callback^)
    _ = empty^
    assert_equal(ledger[].drops[0], 2)
    _ = prefix^
    assert_equal(ledger[].drops[0], 3)
    for i in range(1,5): assert_equal(payloads[].drops[i], 1)


def external_output(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def project(var value: Int) {view} -> View:
        _ = value
        return view
    var callback = flow(partial(add, 0), as_unary(project))
    return iterated(range(2)).map_with_index(callback).collect_list()

def external_input(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def project(offset: Int, first: View, second: View) -> View:
        _ = offset
        _ = second
        return first
    var callback = partial(project, 0)
    var left: List[View] = [view]
    var right: List[View] = [view]
    return iterated(left^).zip_with(right^, callback).collect_list()

def main() raises:
    composition_lifetime()
    flipped_payloads()
    partial_copies()
    var owner: List[Int] = [7, 11]
    var output = external_output(owner)
    assert_true(Pointer(to=output[1][0]) == Pointer(to=owner[0]))
    var input = external_input(owner)
    assert_true(Pointer(to=input[0][1]) == Pointer(to=owner[1]))
