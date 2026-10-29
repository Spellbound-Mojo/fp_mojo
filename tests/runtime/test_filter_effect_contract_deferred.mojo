"""Inferred effectful filtering preserves deferred pulls, calls and errors."""
from algebra_support.filter_effect_contracts import filtered, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily
from algebra_support.iterators import Counted
from fp.iteration import iterated
from fp.effects import Reader, State, run
from fp.callables import BorrowCallable, BorrowSignature
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ReaderAudit(BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Reader[Int].Pure[Bool]
    def invoke(self, value: Int) -> Self.Result:
        self.calls[] += 1
        return Reader[Int].pure(value % 2 == 0)

@fieldwise_init
struct Reject(BorrowCallable):
    comptime Payload = Int
    comptime Result = Reader[Int].Pure[Bool]
    comptime Failure = Int
    def invoke(self, value: Int) raises Int -> Self.Result:
        if value == 2: raise 73
        return Reader[Int].pure(value % 2 == 0)

def main() raises:
    for count in [0,3]:
        var pulls = 0
        var calls = ArcPointer(0)
        var pending = filtered[ListFamily,Reader[Int]](Counted(Pointer(to=pulls),0,count),ReaderAudit(calls))
        assert_equal(pulls,0)
        assert_equal(calls[],0)
        var environment = 10
        assert_equal(run[Reader[Int]](pending^,environment),List[Int]() if count == 0 else List[Int]([2]))
        assert_equal(pulls,count+1)
        assert_equal(calls[],count)
    var calls = ArcPointer(0)
    _ = filtered[ListFamily,Reader[Int]](range(3),ReaderAudit(calls))
    assert_equal(calls[],0)
    def state_audit(value: Int) {calls} -> State[Int].Pure[Bool]:
        calls[] += 1
        return State[Int].pure(value % 2 == 0)
    var state = filtered[ListFamily,State[Int]](range(3),BorrowSignature[Int,State[Int].Pure[Bool]].capture(state_audit))
    assert_equal(calls[],0)
    var output = run[State[Int]](state^,10)
    assert_equal(output[0],[0,2])
    assert_equal(output[1],10)
    assert_equal(calls[],3)
    var pulls = 0
    var failed = filtered[ListFamily,Reader[Int]](Counted(Pointer(to=pulls),0,5),Reject())
    assert_equal(pulls,0)
    var environment = 0
    var caught = 0
    try: _ = run[Reader[Int]](failed^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    assert_equal(pulls,2)

    # A single-value source invokes the predicate while constructing its target.
    caught = 0
    try: _ = filtered[OptionalFamily,Reader[Int]](Optional(2),Reject())
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    calls[] = 0
    var single = filtered[OptionalFamily,Reader[Int]](Optional(2),ReaderAudit(calls))
    assert_equal(calls[],1)
    assert_equal(run[Reader[Int]](single^,environment).value(),2)
    assert_equal(calls[],1)
    calls[] = 0
    var compaction = filtered[FailingCompaction,Reader[Int]](range(3),ReaderAudit(calls))
    assert_equal(calls[],0)
    caught = 0
    try: _ = run[Reader[Int]](compaction^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,83)
    assert_equal(calls[],3)
