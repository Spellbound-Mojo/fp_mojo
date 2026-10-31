"""Observers retain move-only errors and never copy success or observer payloads."""
from fp.algebra import ResultFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct EOOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct EOOnce(BorrowOnceCallable):
    var output: EOOwner
    var failed: Bool
    var throws: Bool
    comptime Payload = EOOwner
    comptime Result = Result[EOOwner, EOOwner]
    comptime Failure = Int
    def invoke_once(deinit self, ref error: EOOwner) raises Int capturing -> Self.Result:
        if self.throws: raise 77
        if self.failed: return Err(self.output^)
        return Ok(self.output^)


def eoo_paths() raises:
    comptime F = ResultFamily[EOOwner]
    for branch in range(4):
        var inputs = ArcPointer(0)
        var outputs = ArcPointer(0)
        var source = Result[EOOwner, EOOwner](Ok(EOOwner(1, inputs))) if branch == 0 else Result[EOOwner, EOOwner](Err(EOOwner(1, inputs)))
        var value: Int
        try:
            var observed = pipeline[F](source^).flat_tap_err(EOOnce(EOOwner(2, outputs), branch == 2, branch == 3)).get()
            if observed.is_ok(): value = observed._ok().value.value
            else: value = observed._err().value.value
        except error: value = error
        assert_equal(value, 77 if branch == 3 else 2 if branch == 2 else 1)
        assert_equal(inputs[], 1)
        assert_equal(outputs[], 1)
    # A discarded stored failure does not replace the original under tap_err.
    var drops = ArcPointer(0)
    var value: Int
    try:
        var tapped = pipeline[F](fail[F, EOOwner](EOOwner(3, drops))).tap_err(EOOnce(EOOwner(4, drops), True, False)).get()
        value = tapped._err().value.value
    except error: value = -1
    assert_equal(value, 3)
    assert_equal(drops[], 2)


def eoo_branching_scope(drops: ArcPointer[Int]) raises:
    comptime L = ResultT[ListFamily, String]
    comptime R = Result[EOOwner, String]
    def observe(error: String) {drops} -> List[R]:
        return [R(Ok(EOOwner(10, drops))), R(Err(String("observer"))), R(Ok(EOOwner(11, drops)))]
    var source: List[R] = [R(Ok(EOOwner(8, drops))), R(Err(String("original")))]
    var result = pipeline[L](source^).flat_tap_err(observe).get()
    assert_equal(len(result), 4)
    assert_equal(result[0]._ok().value.value, 8)
    assert_equal(result[1]._err().value, "original")
    assert_equal(result[2]._err().value, "observer")
    assert_equal(result[3]._err().value, "original")
    assert_equal(drops[], 2)
    assert_equal(result[0]._ok().value.value, 8)


def eoo_move_errors(drops: ArcPointer[Int]) raises:
    comptime L = ResultT[ListFamily, EOOwner]
    def inspect(error: EOOwner) -> Int: return error.value
    var source: List[Result[Int, EOOwner]] = [Result[Int, EOOwner](Err(EOOwner(5, drops))), Result[Int, EOOwner](Err(EOOwner(6, drops)))]
    var tapped = pipeline[L](source^).tap_err(inspect).get()
    assert_equal(tapped[0]._err().value.value, 5)
    assert_equal(tapped[1]._err().value.value, 6)
    assert_equal(drops[], 0)
    assert_equal(tapped[1]._err().value.value, 6)


def eoo_pending(drops: ArcPointer[Int], execute: Bool):
    comptime D = ReaderT[ResultFamily[EOOwner], Int]
    var pending = pipeline[D](fail[D, EOOwner](EOOwner(1, drops))).tap_err(EOOnce(EOOwner(2, drops), True, False)).get()
    if execute:
        try:
            _ = run[D](pending^, 0)
        except error: pass


def main() raises:
    eoo_paths()
    var drops = ArcPointer(0)
    eoo_branching_scope(drops)
    assert_equal(drops[], 3)
    drops[] = 0
    eoo_move_errors(drops)
    assert_equal(drops[], 2)
    drops[] = 0
    eoo_pending(drops, False)
    assert_equal(drops[], 2)
    eoo_pending(drops, True)
    assert_equal(drops[], 4)
    print("error observation ownership: ok")
