"""Outcome-aware pipelines retain move-only bodies, failures and cleanup owners."""
from fp.functions import pipeline
from fp.effects import IO, ExitCase, CancellationToken, delay
from fp.algebra import pure
from fp.callables import OnceThunk, BorrowOnceCallable
from test_io_finalization_owned import FinalizationOwnedError, FinalizationOwnedGuard, FinalizationOwnedBody, FinalizationOwnedObserver
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct CaseOwnedBody(OnceThunk):
    var value: FinalizationOwnedGuard
    comptime Out = FinalizationOwnedGuard
    def call_once(deinit self) -> Self.Out: return self.value^


@fieldwise_init
struct CaseOwnedFactory(BorrowOnceCallable):
    var guard: FinalizationOwnedGuard
    var calls: ArcPointer[Int]
    comptime Payload = ExitCase[Int]
    comptime Result = IO[Int].Pure[NoneType]
    def invoke_once(deinit self, ref exit: Self.Payload) -> Self.Result:
        self.calls[] += 1
        _ = self.guard^
        var unit: NoneType = None
        return pure[IO[Int]](unit)


def main() raises:
    for mode in range(3):
        var bodies = ArcPointer(0)
        var factories = ArcPointer(0)
        var calls = ArcPointer(0)
        var pending = pipeline(delay[Int](CaseOwnedBody(FinalizationOwnedGuard(bodies.copy())))).guarantee_case(CaseOwnedFactory(FinalizationOwnedGuard(factories.copy()),calls.copy()))
        assert_equal(bodies[],0)
        assert_equal(factories[],0)
        assert_equal(calls[],0)
        if mode == 0:
            _ = pending^
        elif mode == 1:
            var token = CancellationToken()
            token.cancel()
            var skipped = pending^.run_io(token)
            assert_equal(Bool(skipped),False)
        else:
            var completed = pending^.run_io()
            assert_equal(bodies[],0)
            assert_equal(factories[],1)
            var result = completed.take()
            var kept = result^._take_ok()
            _ = kept^
        assert_equal(bodies[],1)
        assert_equal(factories[],1)
        assert_equal(calls[],1 if mode==2 else 0)
    var errors = ArcPointer(0)
    var captures = ArcPointer(0)
    var body = delay[FinalizationOwnedError](FinalizationOwnedBody(errors.copy()))
    var observer = FinalizationOwnedObserver(FinalizationOwnedGuard(captures.copy()),errors.copy())
    var completed = pipeline(body^).guarantee_case(observer^).run_io()
    assert_equal(captures[],1)
    assert_equal(errors[],0)
    var failed = completed.take()
    var failure = failed^._take_err()
    var values = failure^.into_errors().into_list()
    assert_equal(len(values),2)
    assert_equal(values[0].text,"body remains alive through effectful cleanup")
    assert_equal(values[1].text,"cleanup error retained alongside body")
    _ = values^
    assert_equal(errors[],2)
    var drops = ArcPointer(0)
    var guard = FinalizationOwnedGuard(drops.copy())
    def borrowed(exit: ExitCase[Int]) {var guard^} -> IO[Int].Pure[NoneType]:
        guard.drops[] += 10
        var unit: NoneType = None
        return pure[IO[Int]](unit)
    var done = pipeline(pure[IO[Int]](7)).guarantee_case(borrowed).run_io()
    assert_equal(done.take().get_or(0),7)
    assert_equal(drops[],10)
    _ = borrowed^
    assert_equal(drops[],11)
