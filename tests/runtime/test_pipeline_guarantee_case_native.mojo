"""Native factories are deferred, masked, borrowed and captured into IO outcomes."""
from fp.functions import pipeline
from fp.algebra import pure
from fp.effects import IO, ExitCase, DelayContract, CancellationToken, delay
from fp.callables import OnceThunk
from test_io_finalization import FinalizationStep
from test_pipeline_io import failure
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct CaseCleanup(OnceThunk):
    var log: ArcPointer[List[Int]]
    var fail: Bool
    comptime Out = NoneType
    comptime Error = Int
    def call_once(deinit self) raises Int -> NoneType:
        self.log[].append(9)
        if self.fail: raise 22
        return None


def main() raises:
    for cancel in range(2):
        for fail in range(2):
            for cleanup in range(3):
                var log = ArcPointer(List[Int]())
                var token = CancellationToken()
                var build_fail = cleanup == 2
                var cleanup_fail = cleanup == 1
                def make(exit: ExitCase[Int]) raises Int {log,build_fail,cleanup_fail} -> DelayContract[CaseCleanup,Int].Out:
                    if exit.is_error(): log[].append(11)
                    elif exit.is_success(): log[].append(1)
                    if exit.is_canceled(): log[].append(3)
                    if build_fail: raise 33
                    return delay[Int](CaseCleanup(log.copy(),cleanup_fail))
                var body = delay[Int](FinalizationStep(log.copy(),token.copy(),Bool(cancel),Bool(fail)))
                var pending = pipeline(body^).raising[Int]().guarantee_case(make)
                assert_equal(log[],List[Int]())
                var result = pending^.run_io(token)
                var expected: List[Int] = [7]
                if fail: expected.append(11)
                elif not cancel: expected.append(1)
                if cancel: expected.append(3)
                if not build_fail: expected.append(9)
                assert_equal(log[],expected)
                if fail or cleanup:
                    var failed = failure(result^)
                    assert_equal(failed.canceled,Bool(cancel))
                    var errors = List[Int]()
                    if fail: errors.append(11)
                    if cleanup: errors.append(22 if cleanup_fail else 33)
                    assert_equal(failed^.into_errors().into_list(),errors)
                elif cancel:
                    assert_equal(Bool(result),False)
                else:
                    assert_equal(result.take().get_or(0),42)
    var calls = 0
    def cleanup(exit: ExitCase[Int]) {mut calls} -> IO[Int].Pure[NoneType]:
        calls += 1
        var unit: NoneType = None
        return pure[IO[Int]](unit)
    var abandoned = pipeline(pure[IO[Int]](7)).guarantee_case(cleanup)
    _ = abandoned^
    assert_equal(calls,0)
    var token = CancellationToken()
    token.cancel()
    var skipped = pipeline(pure[IO[Int]](7)).guarantee_case(cleanup).run_io(token)
    assert_equal(Bool(skipped),False)
    assert_equal(calls,0)
    var done = pipeline(pure[IO[Int]](7)).guarantee_case(cleanup).run_io()
    assert_equal(done.take().get_or(0),7)
    assert_equal(calls,1)
