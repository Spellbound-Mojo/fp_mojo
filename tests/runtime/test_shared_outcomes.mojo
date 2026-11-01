"""Fixed-error validation and outcome selection across capability families."""
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid, ListFamily, StringMonoid, fail
from fp.effects import ResultT, ReaderT, StateT, OptionalT, WriterT, Writer, run, writer, run_writer
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

comptime SOResult = Result[Int, String]
comptime SOFamily = ResultFamily[String]

def so_positive(value: Int) -> Bool: return value > 0
def so_rejected(value: Int) -> String: return "rejected " + String(value)
def so_success(var value: Int) -> String: return "ok " + String(value)
def so_error(var error: String) -> String: return "error " + error
def so_failed_success(var value: Int) -> SOResult: return Err(String("handler"))
def so_recovered(var error: String) -> SOResult: return Ok(42)
def so_observe(outcome: SOResult) -> SOResult: return Ok(0)
def so_failed_observer(outcome: SOResult) -> SOResult: return Err(String("observer"))

def so_transformers() raises:
    comptime R = ReaderT[SOFamily, Int]
    var calls = ArcPointer(0)
    def reject(value: Int) {calls} -> Bool:
        calls[] += 1
        return False
    def factory(value: Int) {calls} -> String:
        calls[] += 10
        return "rejected"
    var checked = pipeline[R](R.pure(2)).ensure(reject, factory).get()
    assert_equal(calls[], 0)
    assert_equal(run[R](checked^, 4)._err().value, "rejected")
    assert_equal(calls[], 11)
    # The two branches may have distinct concrete deferred carrier types.
    def r_ok(var value: Int) -> R.Pure[Int]: return R.pure(value)
    def r_err(var error: String) -> R.Failed[Int]: return fail[R, Int](error^)
    var selected = pipeline[R](R.pure(8)).redeem_with(r_ok, r_err).get()
    assert_equal(run[R](selected^, 4)._ok().value, 8)
    comptime S = StateT[SOFamily, Int]
    def s_ok(var value: Int) -> S.Pure[Int]: return S.pure(value)
    def s_err(var error: String) -> S.Pure[Int]: return S.pure(42)
    var state = pipeline[S](fail[S, Int](String("original"))).redeem_with(s_ok, s_err).get()
    var restored = run[S](state^, 7)
    assert_equal(restored._ok().value[0], 42)
    assert_equal(restored._ok().value[1], 7)
    comptime O = OptionalT[SOFamily]
    def absent(outcome: SOResult) -> O.Pure[Int]: return SOFamily.pure(Optional[Int]())
    var empty = pipeline[O](fail[O, Int](String("original"))).attempt_tap(absent).get()
    assert_true(not empty._ok().value)
    var missing = pipeline[O](O.Pure[Int](Ok(Optional[Int]()))).redeem(so_success, so_error).get()
    assert_true(not missing._ok().value)
    comptime W = WriterT[SOFamily, StringMonoid]
    def log_outcome(outcome: SOResult) -> W.Pure[Int]:
        return writer[W, Int](SOFamily.pure((String("observed"), 0)))
    var failed = pipeline[W](fail[W, Int](String("original"))).attempt_tap(log_outcome).get()
    assert_equal(run_writer[W](failed^)._err().value, "original")
    comptime B = Writer[StringMonoid]
    comptime L = ResultT[B, String]
    def retain_log(outcome: SOResult) -> L.Pure[Int]:
        return writer[B, SOResult]((String("observed"), SOResult(Ok(0))))
    var logged = pipeline[L](fail[L, Int](String("original"))).attempt_tap(retain_log).get()
    var log_result = run_writer[B](logged^)
    assert_equal(log_result[0], "observed")
    assert_equal(log_result[1]._err().value, "original")
    comptime N = ResultT[SOFamily, String]
    var outer = Result[SOResult, String](Err(String("outer")))
    assert_equal(pipeline[N](outer^).redeem(so_success, so_error).get()._err().value, "outer")

def main() raises:
    so_transformers()
    assert_equal(pipeline[SOFamily](SOResult(Ok(3))).ensure(so_positive, so_rejected).get()._ok().value, 3)
    assert_equal(pipeline[SOFamily](SOResult(Ok(-2))).ensure(so_positive, so_rejected).get()._err().value, "rejected -2")
    assert_equal(pipeline[SOFamily](fail[SOFamily, Int](String("original"))).ensure(so_positive, so_rejected).get()._err().value, "original")
    assert_equal(pipeline[SOFamily](SOResult(Ok(3))).redeem(so_success, so_error).get()._ok().value, "ok 3")
    assert_equal(pipeline[SOFamily](fail[SOFamily, Int](String("original"))).redeem(so_success, so_error).get()._ok().value, "error original")
    assert_equal(pipeline[SOFamily](SOResult(Ok(3))).redeem_with(so_failed_success, so_recovered).get()._err().value, "handler")
    assert_equal(pipeline[SOFamily](fail[SOFamily, Int](String("original"))).redeem_with(so_failed_success, so_recovered).get()._ok().value, 42)
    assert_equal(pipeline[SOFamily](SOResult(Ok(3))).attempt_tap(so_observe).get()._ok().value, 3)
    assert_equal(pipeline[SOFamily](fail[SOFamily, Int](String("original"))).attempt_tap(so_observe).get()._err().value, "original")
    assert_equal(pipeline[SOFamily](fail[SOFamily, Int](String("original"))).attempt_tap(so_failed_observer).get()._err().value, "observer")
    comptime V = ValidationFamily[ListMonoid[String]]
    def invalid(var errors: List[String]) -> String: return errors[0].copy()
    assert_equal(pipeline[V](fail[V, Int](List[String](["invalid"]))).redeem(so_success, invalid).get()._ok().value, "invalid")
    comptime L = ResultT[ListFamily, String]
    var entries: List[SOResult] = [SOResult(Ok(2)), SOResult(Err(String("old"))), SOResult(Ok(-1))]
    var checked = pipeline[L](entries^).ensure(so_positive, so_rejected).redeem(so_success, so_error).get()
    assert_equal(checked[0]._ok().value, "ok 2")
    assert_equal(checked[1]._ok().value, "error old")
    assert_equal(checked[2]._ok().value, "error rejected -1")
    def branches(outcome: SOResult) -> List[SOResult]:
        if outcome.is_ok(): return List[SOResult]()
        return [SOResult(Ok(1)), SOResult(Err(String("observer"))), SOResult(Ok(2))]
    var observed = pipeline[L](List[SOResult]([SOResult(Ok(2)), SOResult(Err(String("old")))])).attempt_tap(branches).get()
    assert_equal(len(observed), 3)
    assert_equal(observed[0]._err().value, "old")
    assert_equal(observed[1]._err().value, "observer")
    assert_equal(observed[2]._err().value, "old")
    comptime R = ReaderT[SOFamily, Int]
    var calls = ArcPointer(0)
    def inspect(outcome: SOResult) {calls} -> R.Pure[Int]:
        calls[] += 1
        return R.pure(0)
    var pending = pipeline[R](fail[R, Int](String("original"))).attempt_tap(inspect).redeem(so_success, so_error).get()
    assert_equal(calls[], 0)
    assert_equal(run[R](pending^, 7)._ok().value, "error original")
    assert_equal(calls[], 1)
    print("shared outcomes: ok")
