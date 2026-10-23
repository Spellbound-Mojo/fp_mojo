"""Error observation follows family combination, timing and branching."""
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid, ListFamily, StringMonoid, fail
from fp.effects import ReaderT, StateT, OptionalT, WriterT, ResultT, Writer, writer, run, run_writer
from fp.functions import piped
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

comptime EOR = Result[Int, String]
comptime EOF = ResultFamily[String]


def eo_observe(error: String) -> Result[Int, String]: return Err(String("observer"))
def eo_success(error: String) -> Result[Int, String]: return Ok(8)


def eo_eager() raises:
    assert_equal(piped(fail[EOF, Int](String("original"))).tap_err[EOF](eo_observe).get()._err().value, "original")
    assert_equal(piped(fail[EOF, Int](String("original"))).flat_tap_err[EOF](eo_observe).get()._err().value, "observer")
    assert_equal(piped(fail[EOF, Int](String("original"))).flat_tap_err[EOF](eo_success).get()._err().value, "original")
    var calls = ArcPointer(0)
    def observe(error: String) {calls} -> EOR:
        calls[] += 1
        return Err(String("observer"))
    assert_equal(piped(EOR(Ok(4))).flat_tap_err[EOF](observe).get()._ok().value, 4)
    assert_equal(piped(EOR(Ok(5))).tap_err[EOF](observe).get()._ok().value, 5)
    assert_equal(calls[], 0)
    comptime V = ValidationFamily[ListMonoid[String]]
    def validation_observer(errors: List[String]) -> Result[Int, List[String]]:
        return Err(List[String](["observer1", "observer2"]))
    var accumulated = piped(fail[V, Int](List[String](["original"]))).flat_tap_err[V](validation_observer).get()
    assert_equal(len(accumulated._err().value), 3)
    assert_equal(accumulated._err().value[0], "observer1")
    assert_equal(accumulated._err().value[1], "observer2")
    assert_equal(accumulated._err().value[2], "original")
    comptime L = ResultT[ListFamily, String]
    def branches(error: String) -> List[EOR]:
        if error == "empty": return List[EOR]()
        return List[EOR]([EOR(Ok(1)), EOR(Err(String("observer"))), EOR(Ok(2))])
    var items: List[EOR] = [EOR(Ok(4)), EOR(Err(String("original"))), EOR(Err(String("empty")))]
    var observed = piped(items^).flat_tap_err[L](branches).get()
    assert_equal(len(observed), 4)
    assert_equal(observed[0]._ok().value, 4)
    assert_equal(observed[1]._err().value, "original")
    assert_equal(observed[2]._err().value, "observer")
    assert_equal(observed[3]._err().value, "original")
    var plain: List[EOR] = [EOR(Ok(4)), EOR(Err(String("a"))), EOR(Err(String("b")))]
    var tapped = piped(plain^).tap_err[L](observe).get()
    assert_equal(calls[], 2)
    assert_equal(tapped[1]._err().value, "a")
    comptime N = ResultT[EOF, String]
    var nested = Result[EOR, String](Err(String("outer")))
    var unchanged = piped(nested^).tap_err[N](observe).get()
    assert_equal(unchanged._err().value, "outer")
    assert_equal(calls[], 2)


def eo_transformers() raises:
    comptime R = ReaderT[EOF, Int]
    comptime S = StateT[EOF, Int]
    var calls = ArcPointer(0)
    def inspect(error: String) {calls} -> Int:
        calls[] += 1
        return 0
    def reader_effect(error: String) {calls} -> R.Pure[Int]:
        calls[] += 10
        return R.pure(0)
    var reader = piped(fail[R, Int](String("original"))).tap_err[R](inspect).flat_tap_err[R](reader_effect).get()
    assert_equal(calls[], 0)
    assert_equal(run[R](reader^, 8)._err().value, "original")
    assert_equal(calls[], 11)
    def state_effect(error: String) -> S.Pure[Int]: return S.pure(0)
    var state = piped(fail[S, Int](String("original"))).flat_tap_err[S](state_effect).get()
    assert_equal(run[S](state^, 8)._err().value, "original")
    comptime O = OptionalT[EOF]
    def absent(error: String) -> O.Pure[Int]: return EOF.pure(Optional[Int]())
    var cleared = piped(fail[O, Int](String("original"))).flat_tap_err[O](absent).get()
    assert_true(not cleared._ok().value)
    var absent_source = piped(O.Pure[Int](Ok(Optional[Int]()))).tap_err[O](inspect).get()
    assert_true(not absent_source._ok().value)
    assert_equal(calls[], 11)
    comptime W = WriterT[EOF, StringMonoid]
    def writer_effect(error: String) -> W.Pure[Int]:
        return writer[W, Int](EOF.pure((String("observed"), 0)))
    var written = piped(fail[W, Int](String("original"))).flat_tap_err[W](writer_effect).get()
    assert_equal(run_writer[W](written^)._err().value, "original")
    comptime Base = Writer[StringMonoid]
    comptime Logged = ResultT[Base, String]
    def log_error(error: String) -> Logged.Pure[Int]:
        return writer[Base, EOR]((String("observed"), EOR(Ok(0))))
    var logged = piped(fail[Logged, Int](String("original"))).flat_tap_err[Logged](log_error).get()
    var result = run_writer[Base](logged^)
    assert_equal(result[0], "observed")
    assert_equal(result[1]._err().value, "original")


def main() raises:
    eo_eager()
    eo_transformers()
    print("error observation: ok")
