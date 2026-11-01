"""Scan views retain callbacks independently from move-only carry and output owners."""
from fp.functions import partial, flip, flow, as_unary
from fp.iteration import iterated, scan_map
from fp.callables import Binary
from algebra_support.result_ownership import Token, Trace, trace
from algebra_support.scans import I5Carry, I5Input, I5Output
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Step(Binary):
    comptime First = I5Input
    comptime Second = I5Carry
    comptime Out = Tuple[I5Carry, I5Output]
    var capture: Token
    var outputs: ArcPointer[Int]
    def call(self, var item: I5Input, var carry: I5Carry) -> Self.Out:
        self.capture.trace[].calls += 1
        carry.total += item.value
        var text = "total=" + String(carry.total)
        return (carry^, I5Output(text^, self.outputs))

def owners() raises:
    for count in range(4):
        var ledger = trace()
        var carries = ArcPointer(0)
        var inputs = ArcPointer(0)
        var outputs = ArcPointer(0)
        var callback = flip(Step(Token(0, ledger), outputs))
        comptime assert not conforms_to(type_of(callback), Copyable)
        var source = List[I5Input]()
        for i in range(3): source.append(I5Input(i + 1, inputs))
        var pending = iterated(source^).scan_map(callback, I5Carry(0, carries))
        assert_equal(ledger[].calls, 0)
        assert_equal(inputs[], 0)
        var kept = List[I5Output]()
        for i in range(count):
            kept.append(next(pending))
            assert_equal(kept[i].text, "total=" + String((i + 1) * (i + 2) // 2))
        assert_equal(ledger[].calls, count)
        assert_equal(inputs[], count)
        _ = pending^
        assert_equal(carries[], 1)
        assert_equal(inputs[], 3)
        assert_equal(outputs[], 0)
        assert_equal(ledger[].drops[0], 0)
        var empty = scan_map(List[I5Input](), I5Carry(0, carries), callback)
        assert_equal(len(iterated(empty^).collect_list()), 0)
        assert_equal(carries[], 2)
        assert_equal(ledger[].calls, count)
        var moved = iterated(List[I5Input]()).scan_map(callback^, I5Carry(0, carries))
        _ = moved^
        assert_equal(carries[], 3)
        assert_equal(ledger[].drops[0], 1)
        _ = kept^
        assert_equal(outputs[], count)

@fieldwise_init
struct Prefix(Copyable):
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1

def summed(var prefix: Prefix, carry: Int, item: Int) -> Tuple[Int, Int]:
    prefix.ledger[].calls += 1
    return (carry + item, carry + item)

def copies() raises:
    var ledger = trace()
    var prefix = Prefix(ledger)
    var callback = partial(summed, prefix)
    var pending = iterated(range(1, 3)).scan_map(callback, 0)
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(pending^.collect_list(), [1, 3])
    assert_equal(ledger[].factories, 3)
    assert_equal(ledger[].calls, 2)
    assert_equal(ledger[].drops[0], 2)
    var empty = iterated(range(0)).scan_map(callback^, 0)
    _ = empty^
    assert_equal(ledger[].drops[0], 3)
    _ = prefix^
    assert_equal(ledger[].drops[0], 4)

def external_input(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def step(increment: Int, carry: Int, item: View) -> Tuple[Int, View]: return (carry + increment, item)
    var callback = partial(step, 1)
    var source: List[View] = [view]
    return iterated(source^).scan_map(callback, 0).collect_list()

def external_output(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def add(carry: Int, item: Int) -> Int: return carry + item
    def output(var carry: Int) {view} -> Tuple[Int, View]: return (carry, view)
    var callback = flow(partial(add), as_unary(output))
    return iterated(range(2)).scan_map(callback, 0).collect_list()

def main() raises:
    owners()
    copies()
    var owner: List[Int] = [7, 11]
    var input = external_input(owner)
    var output = external_output(owner)
    assert_true(Pointer(to=input[0][1]) == Pointer(to=owner[1]))
    assert_true(Pointer(to=output[1][0]) == Pointer(to=owner[0]))
