"""Borrowed steps do not add snapshot copies or initial pulls."""
from fp.functions import flip, partial
from fp.iteration import iterated, scan_left
from fp.callables import Binary
from algebra_support.result_ownership import Token, trace
from test_iteration_generic_scan import Snapshot, Source
from test_scan_callback_views_ownership import Prefix
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Append(Binary):
    comptime First = Token
    comptime Second = Snapshot
    comptime Out = Snapshot
    var capture: Token
    def call(self, var item: Token, var snapshot: Snapshot) -> Snapshot:
        self.capture.trace[].calls += 1
        snapshot.values.append(item.id)
        return snapshot^

def snapshots() raises:
    for count in range(4):
        var copies = ArcPointer(0)
        var drops = ArcPointer(0)
        var pulls = ArcPointer(0)
        var captures = trace()
        var payloads = trace()
        def token(var value: Int) {payloads} -> Token: return Token(value, payloads)
        var callback = flip(Append(Token(0, captures)))
        comptime assert not conforms_to(type_of(callback), Copyable)
        var source = iterated(Source(0, 2, pulls)).map(token)
        var pending = scan_left(source^, Snapshot(List[Int](), copies, drops), callback)
        assert_equal(copies[], 0)
        assert_equal(pulls[], 0)
        assert_equal(captures[].calls, 0)
        var retained = List[Snapshot]()
        for i in range(count):
            retained.append(next(pending))
            assert_equal(copies[], i + 1)
            assert_equal(pulls[], i)
            assert_equal(captures[].calls, i)
            assert_equal(len(retained[i].values), i)
        if count == 3:
            for _ in range(2):
                var stopped = False
                try: _ = next(pending)
                except StopIteration: stopped = True
                assert_true(stopped)
            assert_equal(pulls[], 3)
            assert_equal(copies[], 3)
            assert_equal(captures[].calls, 2)
        if count:
            retained[0].values.append(99)
            for i in range(1, count): assert_equal(len(retained[i].values), i)
        _ = pending^
        assert_equal(drops[], 1)
        assert_equal(captures[].drops[0], 0)
        for i in range(1, 3): assert_equal(payloads[].drops[i], Int(i < count))
        var empty = iterated(List[Token]()).scan_left(callback, Snapshot(List[Int](), copies, drops)).collect_list()
        assert_equal(len(empty), 1)
        assert_equal(copies[], count + 1)
        assert_equal(drops[], 2)
        _ = empty^
        assert_equal(drops[], 3)
        var moved = iterated(List[Token]()).scan_left(callback^, Snapshot(List[Int](), copies, drops))
        _ = moved^
        assert_equal(copies[], count + 1)
        assert_equal(drops[], 4)
        assert_equal(captures[].drops[0], 1)
        _ = retained^
        assert_equal(drops[], count + 4)

def summed(var prefix: Prefix, carry: Int, item: Int) -> Int:
    prefix.ledger[].calls += 1
    return carry + item

def prefix_copies() raises:
    var ledger = trace()
    var prefix = Prefix(ledger)
    var callback = partial(summed, prefix)
    var pending = iterated(range(1, 3)).scan_left(callback, 0)
    assert_equal(ledger[].factories, 1)
    assert_equal(next(pending), 0)
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(pending^.collect_list(), [1, 3])
    assert_equal(ledger[].factories, 3)
    assert_equal(ledger[].calls, 2)
    var initial_only = iterated(range(3)).scan_left(callback, 9).take(1).collect_list()
    assert_equal(initial_only, [9])
    assert_equal(ledger[].factories, 3)
    assert_equal(ledger[].calls, 2)
    _ = callback^
    assert_equal(ledger[].drops[0], 3)
    _ = prefix^
    assert_equal(ledger[].drops[0], 4)

def external(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(preferred: View, carry: View, item: Int) -> View:
        _ = carry
        _ = item
        return preferred
    var callback = partial(keep, view)
    return iterated(range(2)).scan_left(callback, view).collect_list()

def main() raises:
    snapshots()
    prefix_copies()
    var owner: List[Int] = [7, 11]
    var values = external(owner)
    assert_equal(len(values), 3)
    for i in range(3): assert_true(Pointer(to=values[i][1]) == Pointer(to=owner[1]))
