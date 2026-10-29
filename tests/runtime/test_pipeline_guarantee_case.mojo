"""Selected finalization retains body types and every scoped outcome channel."""
from fp.functions import pipeline, Pipeline
from fp.algebra import Functor, pure
from fp.effects import IO, IOContract, GuaranteeCaseContract, ReaderAction, ScopedIO, ExitCase, CancellationToken, delay, scoped_io
from test_io_finalization import FinalizationStep, FinalizationObserver, finalization_native
from test_pipeline_io import failure
from std.memory import ArcPointer
from std.testing import assert_equal


def protected[I: Functor, P: ReaderAction, F: ScopedIO](var source: Pipeline[I,P], var finalizer: F
) -> Pipeline[GuaranteeCaseContract[P,F].Family,GuaranteeCaseContract[P,F].Out] where I == P.Family and IOContract[P].Compatible and GuaranteeCaseContract[P,F].Compatible:
    return source^.guarantee_case(finalizer^)


def main() raises:
    for cancel in range(2):
        for fail in range(2):
            for cleanup in range(3):
                var log = ArcPointer(List[Int]())
                var token = CancellationToken()
                var body = delay[Int](FinalizationStep(log.copy(),token.copy(),Bool(cancel),Bool(fail)))
                var pending = protected(pipeline(body^),FinalizationObserver(log.copy(),cleanup==1,cleanup==2))
                assert_equal(log[],List[Int]())
                var result = pending^.run_io(token)
                var expected: List[Int] = [7]
                if cleanup != 2:
                    if fail: expected.append(11)
                    elif not cancel: expected.append(1)
                    if cancel: expected.append(3)
                assert_equal(log[],expected)
                if fail or cleanup:
                    var failed = failure(result^)
                    assert_equal(failed.canceled,Bool(cancel))
                    var errors = List[Int]()
                    if fail: errors.append(11)
                    if cleanup: errors.append(22 if cleanup==1 else 33)
                    assert_equal(failed^.into_errors().into_list(),errors)
                elif cancel:
                    assert_equal(Bool(result),False)
                else:
                    assert_equal(result.take().get_or(0),42)
    var adapted = pipeline(pure[IO[Int]](9)).guarantee_case(scoped_io(finalization_native)).run_io()
    assert_equal(adapted.take().get_or(0),9)
    var native = pipeline(pure[IO[Int]](11)).guarantee_case(finalization_native).run_io()
    assert_equal(native.take().get_or(0),11)
    var stored: def(ExitCase[Int]) thin -> IO[Int].Pure[NoneType] = finalization_native
    var thin = pipeline(pure[IO[Int]](13)).guarantee_case(stored).run_io()
    assert_equal(thin.take().get_or(0),13)
    var log = ArcPointer(List[Int]())
    var token = CancellationToken()
    token.cancel()
    var unopened = pipeline(pure[IO[Int]](1)).guarantee_case(FinalizationObserver(log.copy(),False,False)).run_io(token)
    assert_equal(Bool(unopened),False)
    assert_equal(log[],List[Int]())
    assert_equal(token.requested(),True)
