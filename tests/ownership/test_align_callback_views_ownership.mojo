"""Alignment views preserve callback lifetime, Ior payload ownership and origins."""
from fp.functions import partial, as_unary
from fp.iteration import align_with, iterated
from fp.data import Ior, Left, Right, Both
from fp.data.ior import _ior_parts
from algebra_support.result_ownership import Token, Trace, trace
from algebra_support.alignment import I4Source, i4_done, i4_total
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true


def trace_alignment() raises:
    var ledger = trace()
    var state = Token(0, ledger)
    def project(var value: Ior[Int, Int]) {var state^} -> Int:
        state.trace[].calls += 1
        return i4_total(value^)
    var callback = as_unary(project^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    var pulls = ArcPointer(List[Int]())
    var drops = ArcPointer(0)
    var pending = align_with(callback, I4Source(0,2,1,pulls,drops), I4Source(0,1,2,pulls,drops))
    assert_equal(len(pulls[]), 0)
    assert_equal(ledger[].calls, 0)
    assert_equal(next(pending), 0)
    assert_equal(next(pending), 1)
    i4_done(pending)
    assert_equal(pulls[], [100,200,101,201,102])
    assert_equal(ledger[].calls, 2)
    _ = pending^
    assert_equal(drops[], 2)
    assert_equal(ledger[].drops[0], 0)
    pulls[].clear()
    var abandoned = iterated(I4Source(0,3,1,pulls,drops)).align_with(I4Source(0,2,2,pulls,drops), callback)
    assert_equal(next(abandoned), 0)
    _ = abandoned^
    assert_equal(pulls[], [100,200])
    assert_equal(drops[], 4)
    assert_equal(ledger[].drops[0], 0)
    var empty = iterated(range(0)).align_with(range(0), callback^)
    assert_equal(len(empty^.collect_list()), 0)
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].drops[0], 1)


def owned_payloads() raises:
    var captures = trace()
    var payloads = trace()
    var state = Token(0, captures)
    def left_first(var value: Ior[Token, Token]) {var state^} -> Token:
        state.trace[].calls += 1
        var left = Optional[Token]()
        var right = Optional[Token]()
        _ior_parts(value^).split(left, right)
        if left: return left.unsafe_take()
        return right.unsafe_take()
    var callback = as_unary(left_first^)
    var left: List[Token] = [Token(1, payloads), Token(2, payloads)]
    var right: List[Token] = [Token(3, payloads)]
    var pending = iterated(left^).align_with(right^, callback)
    assert_equal(captures[].calls, 0)
    var retained = next(pending)
    assert_equal(retained.id, 1)
    assert_equal(payloads[].drops[1], 0)
    assert_equal(payloads[].drops[3], 1)
    _ = pending^
    assert_equal(payloads[].drops[2], 1)
    assert_equal(captures[].drops[0], 0)
    var tail: List[Token] = [Token(4, payloads)]
    var remaining = iterated(align_with(callback, List[Token](), tail^)).collect_list()
    assert_equal(remaining[0].id, 4)
    assert_equal(captures[].calls, 2)
    _ = remaining^
    _ = retained^
    _ = callback^
    assert_equal(captures[].drops[0], 1)
    for i in range(1,5): assert_equal(payloads[].drops[i], 1)


@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def count_parts(var prefix: Prefix, value: Ior[Token, Token]) -> Int:
    prefix.ledger[].calls += 1
    if value.isa[Left[Token]]():
        prefix.ledger[].restarts += value[Left[Token]].value.trace[].drops[value[Left[Token]].value.id]
        return 1
    if value.isa[Right[Token]](): return 1
    prefix.ledger[].restarts += value[Both[Token, Token]].left.trace[].drops[value[Both[Token, Token]].left.id]
    return 2

def partial_copies() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var callback = partial(count_parts, prefix)
    var left: List[Token] = [Token(1, payloads), Token(2, payloads)]
    var right: List[Token] = [Token(3, payloads)]
    var pending = iterated(left^).align_with(right^, callback)
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(next(pending), 2)
    assert_equal(next(pending), 1)
    i4_done(pending)
    assert_equal(ledger[].calls, 2)
    assert_equal(ledger[].factories, 3)
    assert_equal(ledger[].restarts, 0)
    _ = pending^
    assert_equal(ledger[].drops[0], 2)
    _ = callback^
    assert_equal(ledger[].drops[0], 3)
    _ = prefix^
    assert_equal(ledger[].drops[0], 4)
    for i in range(1,4): assert_equal(payloads[].drops[i], 1)


def external_output(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def project(var value: Ior[Int, Int]) {view} -> View:
        _ = value^
        return view
    var callback = as_unary(project)
    return iterated(range(1)).align_with(range(2), callback).collect_list()

def external_input(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def project(offset: Int, value: Ior[View, Int]) -> View:
        _ = offset
        if value.isa[Left[View]](): return value[Left[View]].value
        return value[Both[View, Int]].left
    var callback = partial(project, 0)
    var values: List[View] = [view, view]
    return iterated(values^).align_with(range(1), callback).collect_list()

def main() raises:
    trace_alignment()
    owned_payloads()
    partial_copies()
    var owner: List[Int] = [7, 11]
    var output = external_output(owner)
    assert_true(Pointer(to=output[1][0]) == Pointer(to=owner[0]))
    var input = external_input(owner)
    assert_true(Pointer(to=input[1][1]) == Pointer(to=owner[1]))
