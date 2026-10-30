"""Counting, sinks and optional folds retain shared owners through cleanup."""
from fp.functions import partial, as_unary
from fp.iteration import iterated, count_where, for_each, collect_fold
from fp.algebra import Monoid
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


def pulled(var value: Token) -> Token:
    value.trace[].pulls += 1
    return value^


def sinks() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def record(var value: Token) {var state^} -> NoneType:
        state.trace[].calls += value.id
        return None
    var sink = as_unary(record^)
    comptime assert not conforms_to(type_of(sink), Copyable)
    var first: List[Token] = [Token(1, payloads), Token(2, payloads)]
    for_each(first^, sink)
    var second: List[Token] = [Token(3, payloads)]
    iterated(second^).for_each(sink)
    for_each(List[Token](), sink)
    assert_equal(ledger[].calls, 6)
    assert_equal(ledger[].drops[0], 0)
    var last: List[Token] = [Token(4, payloads)]
    iterated(last^).for_each(sink^)
    assert_equal(ledger[].calls, 10)
    assert_equal(ledger[].drops[0], 1)
    for i in range(1, 5): assert_equal(payloads[].drops[i], 1)


@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def selected(var prefix: Prefix, value: Token) -> Bool:
    prefix.ledger[].calls += 1
    prefix.ledger[].restarts += value.trace[].drops[value.id]
    return value.id < 3

def counted() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var predicate = partial(selected, prefix)
    assert_equal(count_where(List[Token](), predicate), 0)
    assert_equal(ledger[].factories, 1)
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads)]
    assert_equal(iterated(values^).count_where(predicate), 2)
    assert_equal(ledger[].factories, 4)
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].restarts, 0)
    assert_equal(ledger[].drops[0], 3)
    assert_equal(count_where(List[Token](), predicate^), 0)
    assert_equal(ledger[].drops[0], 4)
    _ = prefix^
    assert_equal(ledger[].drops[0], 5)
    for i in range(1, 4): assert_equal(payloads[].drops[i], 1)


@fieldwise_init
struct Total(Movable):
    var value: Int

struct Totals(Monoid):
    comptime Value = Total
    @staticmethod
    def empty() -> Total: return Total(0)
    @staticmethod
    def combine(var left: Total, var right: Total) -> Total:
        return Total(left.value + right.value)

struct FailedIdentity(Monoid):
    comptime Value = Total
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Total: raise 9
    @staticmethod
    def combine(var left: Total, var right: Total) raises Int -> Total:
        return Total(left.value + right.value)


def optional_fold() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def select(var value: Token) {var state^} -> Optional[Total]:
        state.trace[].calls += 1
        if value.id % 2 == 0: return Optional(Total(value.id))
        return None
    var project = as_unary(select^)
    comptime assert not conforms_to(type_of(project), Copyable)
    var first: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads), Token(4, payloads)]
    var result = collect_fold[Totals](first^, project)
    comptime assert not conforms_to(type_of(result), Copyable)
    assert_equal(result.value, 6)
    assert_equal(iterated(List[Token]()).collect_fold[Totals](project).value, 0)
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].drops[0], 0)
    var last: List[Token] = [Token(5, payloads), Token(6, payloads)]
    assert_equal(iterated(last^).collect_fold[Totals](project^).value, 6)
    assert_equal(ledger[].calls, 6)
    assert_equal(ledger[].drops[0], 1)
    for i in range(1, 7): assert_equal(payloads[].drops[i], 1)


def errors() raises:
    var ledger = trace()
    var payloads = trace()
    var state = Token(0, ledger)
    def select(var value: Token) raises Token {var state^} -> Optional[Total]:
        state.trace[].calls += 1
        raise Token(value.id, state.trace)
    var project = as_unary(select^)
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads)]
    var caught = False
    try: _ = iterated(values^).map(pulled).collect_fold[Totals](project)
    except error:
        comptime assert type_of(error) == Token
        assert_equal(error.id, 1)
        caught = True
    assert_true(caught)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].drops[1], 1)
    assert_equal(ledger[].drops[0], 0)
    assert_equal(payloads[].pulls, 1)
    _ = project^
    assert_equal(ledger[].drops[0], 1)
    for i in range(1, 4): assert_equal(payloads[].drops[i], 1)
    var state2 = Token(4, ledger)
    def never_called(var value: Token) {var state2^} -> Optional[Total]:
        state2.trace[].calls += 1
        return Optional(Total(value.id))
    var callback = as_unary(never_called^)
    var unopened: List[Token] = [Token(5, payloads), Token(6, payloads)]
    var code = 0
    try: _ = collect_fold[FailedIdentity](iterated(unopened^).map(pulled), callback)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 9)
    assert_equal(ledger[].calls, 1)
    assert_equal(payloads[].pulls, 1)
    assert_equal(payloads[].drops[5], 1)
    assert_equal(payloads[].drops[6], 1)
    assert_equal(ledger[].drops[4], 0)
    _ = callback^
    assert_equal(ledger[].drops[4], 1)


def outside(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def select(size: Int, value: View) -> Optional[List[View]]:
        if len(value) >= size: return Optional(List[View]([value]))
        return None
    from fp.algebra import ListMonoid
    var project = partial(select, 1)
    var values: List[View] = [view]
    return iterated(values^).collect_fold[ListMonoid[View]](project)


def main() raises:
    sinks()
    counted()
    optional_fold()
    errors()
    var owner: List[Int] = [7, 11]
    var retained = outside(owner)
    assert_true(Pointer(to=retained[0][1]) == Pointer(to=owner[1]))
