"""Writer output selection preserves base carriers and public generic contracts."""
from fp.effects import Writer, WriterT, WriterFamily, WriterValueContract, WriterLogContract, Reader, writer, tell, run_value, run_log, asks
from fp.algebra import IdentityFamily, StringMonoid, OptionalFamily, ResultFamily
from fp.functions import pipeline, Pipeline
from fp.data import Result, Err
from algebra_support.external import PublicMonad
from std.testing import assert_equal


def value[I: WriterFamily,V: Movable & Deinitable](var source: V) raises WriterValueContract[I,V].Error -> WriterValueContract[I,V].Out where WriterValueContract[I,V].Compatible:
    return run_value[I](source^)


def log[I: WriterFamily,V: Movable & Deinitable,E: Movable & Deinitable](var source: Pipeline[I,V,E]) raises WriterLogContract[I,V].Error -> WriterLogContract[I,V].Out where WriterLogContract[I,V].Compatible:
    return source^.run_log()


def main() raises:
    comptime W = Writer[StringMonoid]
    assert_equal(log(pipeline(tell[W](String("ready")))),"ready")
    assert_equal(value[W](writer[W,Int]((String("log"),7))),7)
    assert_equal(pipeline(writer[W,Int]((String("log"),8))).run_value(),8)
    var unit = run_value[W](tell[W](String("unit")))
    comptime assert type_of(unit) == NoneType
    _ = unit

    comptime O = WriterT[OptionalFamily,StringMonoid]
    assert_equal(value[O](writer[O,Int](Optional((String("log"),11)))).value(),11)
    assert_equal(log(pipeline(writer[O,Int](Optional((String("log"),11))))).value(),"log")
    assert_equal(Bool(pipeline(writer[O,Int](Optional[Tuple[String,Int]]())).run_value()),False)
    assert_equal(Bool(run_log[O](writer[O,Int](Optional[Tuple[String,Int]]()))),False)

    comptime R = WriterT[ResultFamily[String],StringMonoid]
    assert_equal(value[R](R.pure(12)).get_or(-1),12)
    assert_equal(log(pipeline(R.pure(12))).get_or("wrong"),"")
    assert_equal(pipeline(writer[R,Int](Result[Tuple[String,Int],String](Err(String("stop"))))).run_value().is_err(),True)
    assert_equal(run_log[R](writer[R,Int](Result[Tuple[String,Int],String](Err(String("stop"))))).is_err(),True)

    var calls = 0
    def counted(env: Int) {mut calls} -> Tuple[String,Int]:
        calls += 1
        return (String("deferred"),env + 1)
    comptime D = WriterT[Reader[Int],StringMonoid]
    var pending = pipeline(writer[D,Int](asks[Reader[Int]](counted))).run_value()
    assert_equal(calls,0)
    assert_equal(pipeline(pending^).run(20),21)
    assert_equal(calls,1)
    var pending_log = log(pipeline(writer[D,Int](asks[Reader[Int]](counted))))
    assert_equal(calls,1)
    assert_equal(pipeline(pending_log^).run(20),"deferred")
    assert_equal(calls,2)

    comptime F = WriterT[PublicMonad[IdentityFamily,1],StringMonoid]
    for log_only in range(2):
        var observed = 0
        try:
            if log_only: _ = log(pipeline(writer[F,Int]((String("log"),7))).raising[String]())
            else: _ = pipeline(writer[F,Int]((String("log"),7))).raising[String]().run_value()
        except error:
            comptime assert type_of(error) == Int
            observed = error
        assert_equal(observed,702)
