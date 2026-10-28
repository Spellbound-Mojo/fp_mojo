"""Mutable scan state preserves initial-first copies, cleanup and origins."""
from fp.callables import MutableBinary
from fp.iteration import iterated, scan_left
from algebra_support.result_ownership import Token, trace
from test_iteration_generic_scan import Snapshot, Source
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Append(MutableBinary):
    comptime First = Snapshot
    comptime Second = Token
    comptime Out = Snapshot
    var capture: Token
    var calls: Int
    def call_mut(mut self, var snapshot: Snapshot, var item: Token) -> Snapshot:
        self.calls += 1
        self.capture.trace[].calls += 1
        snapshot.values.append(item.id + self.calls)
        return snapshot^

def snapshots() raises:
    for count in range(4):
        var copies = ArcPointer(0)
        var drops = ArcPointer(0)
        var pulls = ArcPointer(0)
        var captures = trace()
        var payloads = trace()
        def token(var value: Int) {payloads} -> Token: return Token(value, payloads)
        var callback = Append(Token(0, captures), 0)
        comptime assert not conforms_to(type_of(callback), Copyable)
        var source = iterated(Source(0, 2, pulls)).map(token)
        var pending = scan_left(callback^, Snapshot(List[Int](), copies, drops), source^)
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
            for j in range(i): assert_equal(retained[i].values[j], 2 * (j + 1))
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
        assert_equal(captures[].drops[0], 1)
        for i in range(1, 3): assert_equal(payloads[].drops[i], Int(i < count))
        _ = retained^
        assert_equal(drops[], count + 1)

@fieldwise_init
struct KeepSpan[o: ImmOrigin](MutableBinary):
    comptime First = Span[Int, Self.o]
    comptime Second = Int
    comptime Out = Span[Int, Self.o]
    var calls: Int
    def call_mut(mut self, var carry: Self.First, var value: Int) -> Self.Out:
        self.calls += 1
        return carry

def external(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    return iterated(range(2)).scan_left(KeepSpan[origin_of(owner)](0), view).collect_list()

def main() raises:
    snapshots()
    var owner: List[Int] = [7, 11]
    var values = external(owner)
    assert_equal(len(values), 3)
    for i in range(3): assert_true(Pointer(to=values[i][1]) == Pointer(to=owner[1]))
