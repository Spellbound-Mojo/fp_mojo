"""Uniform Writer execution keeps generic admission, exact carriers and timing."""
from fp.effects import Writer, WriterT, WriterFamily, writer, run, run_writer, Reader, State, asks, get
from fp.effects.writer import run_writer as legacy_run
from fp.algebra import StringMonoid, ListMonoid, OptionalFamily, ResultFamily, IdentityFamily
from fp.functions import pipeline
from fp.data import Result, Err
from algebra_support.external import PublicMonad
from std.testing import assert_equal


def unwrap[I: WriterFamily,V: Movable & Deinitable](var value: V) -> I.Unwrapped[V] where I.CarrierCompatible[V]:
    return run[I](value^)


def pure_run[I: WriterFamily,A: Movable & Deinitable](var value: A) -> I.Unwrapped[I.Pure[A]] where I.CarrierCompatible[I.Pure[A]]:
    return run[I](I.pure(value^))


def origins(values: List[Int],logs: List[Int],errors: List[Int]) raises:
    comptime V = Span[Int,origin_of(values)]
    comptime L = Span[Int,origin_of(logs)]
    comptime E = Span[Int,origin_of(errors)]
    comptime W = Writer[ListMonoid[L]]
    var pair = unwrap[W](writer[W,V]((List[L]([Span(logs)]),Span(values))))
    comptime assert type_of(pair) == Tuple[List[L],V]
    assert_equal(pair[0][0][0],23)
    assert_equal(pair[1][0],11)
    comptime D = WriterT[Reader[Int],ListMonoid[L]]
    var error_view = Span(errors)
    def fail(env: Int) raises E {error_view} -> Tuple[List[L],V]: raise error_view
    var pending = run[D](writer[D,V](asks[Reader[Int]](fail)))
    var observed: Optional[E] = None
    try: _ = run[Reader[Int]](pending^,0)
    except error:
        comptime assert type_of(error) == E
        observed = Optional(error)
    assert_equal(observed.take()[0],71)


def main() raises:
    origins([11],[23],[71])
    comptime W = Writer[StringMonoid]
    assert_equal(unwrap[W](writer[W,Int]((String("log"),7))),(String("log"),7))
    assert_equal(pure_run[W](8),(String(),8))
    assert_equal(run_writer[W](W.pure(9)),run[W](W.pure(9)))
    assert_equal(legacy_run[W](W.pure(10)),pipeline(W.pure(10)).run())
    comptime O = WriterT[OptionalFamily,StringMonoid]
    var present = unwrap[O](O.pure(11))
    comptime assert type_of(present) == Optional[Tuple[String,Int]]
    assert_equal(present.value(),(String(),11))
    assert_equal(Bool(run[O](writer[O,Int](Optional[Tuple[String,Int]]()))),False)
    comptime R = WriterT[ResultFamily[String],StringMonoid]
    var failed = run[R](writer[R,Int](Result[Tuple[String,Int],String](Err(String("stop")))))
    comptime assert type_of(failed) == Result[Tuple[String,Int],String]
    assert_equal(failed.is_err(),True)
    # Unwrapping needs no map and cannot acquire a base-map construction error.
    comptime F = WriterT[PublicMonad[IdentityFamily,1],StringMonoid]
    assert_equal(unwrap[F](writer[F,Int]((String("log"),12))),(String("log"),12))
    comptime D = WriterT[Reader[Int],StringMonoid]
    var calls = 0
    def counted(env: Int) {mut calls} -> Tuple[String,Int]:
        calls += 1
        return (String("deferred"),env + 1)
    var pending = run[D](writer[D,Int](asks[Reader[Int]](counted)))
    assert_equal(calls,0)
    assert_equal(run[Reader[Int]](pending^,20),(String("deferred"),21))
    assert_equal(calls,1)
    assert_equal(run[State[Int]](get[State[Int]](),23),(23,23))
