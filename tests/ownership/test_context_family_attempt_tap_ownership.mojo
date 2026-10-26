"""Selected attempt_tap owns once observers and deferred outcome storage exactly once."""
from fp.algebra import ResultFamily, ListFamily
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_shared_outcomes_ownership import SOOwner, SOObserver

comptime Deferred = ResultT[Reader[Int], SOOwner]

@fieldwise_init
struct DeferredObserver(BorrowOnceCallable):
    var token: SOOwner
    var calls: ArcPointer[Int]
    var mode: Int
    comptime Payload = Result[SOOwner, SOOwner]
    comptime Result = Deferred.Pure[SOOwner]
    comptime Failure = Int
    def invoke_once(deinit self, ref outcome: Self.Payload) raises Int capturing -> Self.Result:
        self.calls[] += 1
        if self.mode == 2: raise 753
        if self.mode == 1: return Deferred.fail[SOOwner](self.token^)
        return Deferred.pure(self.token^)

def deferred(drops: ArcPointer[Int], calls: ArcPointer[Int], failed: Bool, mode: Int, execute: Bool) raises -> Int:
    var source = Deferred.fail[SOOwner](SOOwner(1, drops)) if failed else Deferred.pure(SOOwner(1, drops))
    var pending = pipeline[Deferred](source^).attempt_tap(DeferredObserver(SOOwner(2, drops), calls, mode)).get()
    assert_equal(calls[], 0)
    assert_equal(drops[], 0)
    if not execute: return 0
    try:
        var outcome = run[Reader[Int]](pending^, 0)
        if outcome.is_ok(): return outcome._ok().value.value
        return outcome._err().value.value
    except error:
        comptime assert type_of(error) == Int
        return error

def immediate(drops: ArcPointer[Int], failed: Bool, mode: Int) -> Int:
    comptime O = Result[SOOwner, SOOwner]
    var source = O(Err(SOOwner(1, drops))) if failed else O(Ok(SOOwner(1, drops)))
    try:
        var outcome = pipeline(source^).attempt_tap(SOObserver(SOOwner(2, drops), mode == 1, mode == 2)).get()
        if outcome.is_ok(): return outcome._ok().value.value
        return outcome._err().value.value
    except error: return error

def branches(drops: ArcPointer[Int]) raises:
    comptime I = ResultT[ListFamily, String]
    def observe(outcome: Result[Int, String]) {drops} -> List[Result[SOOwner, String]]:
        return [Result[SOOwner, String](Ok(SOOwner(1, drops))), Result[SOOwner, String](Ok(SOOwner(2, drops)))]
    var kept = pipeline[I](I.pure(7)).attempt_tap(observe).get()
    assert_equal(len(kept), 2)
    assert_equal(kept[0]._ok().value, 7)
    assert_equal(kept[1]._ok().value, 7)
    assert_equal(drops[], 2)
    var values = List[Result[Int, String]]([Result[Int, String](Ok(1)), Result[Int, String](Ok(2))])
    var calls = 0
    def mutable(outcome: Result[Int, String]) {mut calls} -> List[Result[Int, String]]:
        calls += 1
        if calls == 2: return [Result[Int, String](Err(String("second")))]
        return [Result[Int, String](Ok(0))]
    var seen = pipeline[I](values^).attempt_tap(mutable).get()
    assert_equal(calls, 2)
    assert_equal(seen[0]._ok().value, 1)
    assert_equal(seen[1]._err().value, "second")

def main() raises:
    branches(ArcPointer(0))
    for failed in range(2):
        for mode in range(3):
            var drops = ArcPointer(0)
            var calls = ArcPointer(0)
            assert_equal(deferred(drops, calls, Bool(failed), mode, True), 1 if mode == 0 else 2 if mode == 1 else 753)
            assert_equal(calls[], 1)
            assert_equal(drops[], 2)
            var immediate_drops = ArcPointer(0)
            assert_equal(immediate(immediate_drops, Bool(failed), mode), 1 if mode == 0 else 2 if mode == 1 else 74)
            assert_equal(immediate_drops[], 2)
        var abandoned = ArcPointer(0)
        var skipped = ArcPointer(0)
        assert_equal(deferred(abandoned, skipped, Bool(failed), 0, False), 0)
        assert_equal(skipped[], 0)
        assert_equal(abandoned[], 2)
