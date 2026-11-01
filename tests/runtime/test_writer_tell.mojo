"""Appending logs preserves scope, payload, transformer order and generic APIs."""
from fp.algebra import Functor, StringMonoid, ResultFamily, fail
from fp.effects import Censor, TellContract, Writer, WriterT, ReaderT, ResultT, LiftCensor, writer, tell, run, run_writer
from fp.functions import Pipeline, pipeline
from std.testing import assert_equal


def append[C: Censor, V: Movable & Deinitable](var value: V, var log: C.Log.Value
) raises TellContract[C,V].Error -> TellContract[C,V].Out where TellContract[C,V].Compatible:
    return tell[C](log^, value^)


def fluent[I: Functor & Censor, V: Movable & Deinitable](var source: Pipeline[I,V], var log: I.Log.Value
) raises TellContract[I,V].Error -> Pipeline[TellContract[I,V].Family,TellContract[I,V].Out] where TellContract[I,V].Compatible:
    return source^.tell(log^)


def main() raises:
    comptime W = Writer[StringMonoid]
    var source = writer[W,Int]((String("a"),7))
    comptime assert TellContract[W,type_of(source)].Compatible
    comptime assert TellContract[W,type_of(source)].Error == Never
    var result = pipeline(source^).tell("b").tell("c").listen().tell("d").run()
    assert_equal(result[0],"abcd")
    assert_equal(result[1],(7,String("abc")))
    assert_equal(pipeline(append[W](writer[W,Int]((String("a"),7)),String("b"))).run(),(String("ab"),7))
    assert_equal(fluent[W](pipeline(writer[W,Int]((String("a"),7))),String("b")).run(),(String("ab"),7))
    var notice = run_writer[W](tell[W]("a"))
    assert_equal(notice[0],"a")
    comptime assert type_of(notice[1]) == NoneType

    comptime R = ReaderT[W,Int]
    comptime C = LiftCensor[R,W]
    var pending = append[C](R.lift(writer[W,Int]((String("a"),7))),String("b"))
    assert_equal(run_writer[W](run[R](pending^,0)),(String("ab"),7))

    # Selecting an inner log never changes a same-typed outer log.
    comptime Nested = WriterT[W,StringMonoid]
    comptime Inner = LiftCensor[Nested,W]
    var nested = writer[Nested,Int](writer[W,Tuple[String,Int]]((String("inner"),(String("outer"),7))))
    var scoped = tell[Inner]("!",nested^)
    var logs = run_writer[W](pipeline(scoped^).tell("?").run())
    assert_equal(logs,(String("inner!"),(String("outer?"),7)))

    # A retained log can be extended even when its payload is a stored failure.
    comptime T = ResultT[W,String]
    comptime TC = LiftCensor[T,W]
    var kept = run_writer[W](tell[TC]("after",fail[T,Int](String("stored"))))
    assert_equal(kept[0],"after")
    assert_equal(kept[1]._err().value,"stored")
    comptime Lost = WriterT[ResultFamily[String],StringMonoid]
    var lost = pipeline(fail[Lost,Int](String("lost"))).tell("after").run()
    assert_equal(lost._err().value,"lost")
