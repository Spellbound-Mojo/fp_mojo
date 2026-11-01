"""Selected effect runners preserve family admission, timing and exact types."""
from fp.functions import pipeline, Pipeline
from fp.effects import Reader, ReaderAction, ReaderFamily, ReaderT, State, StateAction, StateFamily, Writer, WriterFamily, WriterT, ask, get, writer, asks, inspect
from fp.algebra import StringMonoid
from context_reader_run_support import FailRead
from std.testing import assert_equal

def twice(var value: Int) -> Int: return value * 2

def reader[I: ReaderFamily, V: ReaderAction, o: ImmOrigin](var value: Pipeline[I,V], ref[o] env: I.Environment) raises V.Error[o] -> V.Out[o] where I.RunCompatible[V,o]:
    return value^.run(env)

def state[I: StateFamily, V: StateAction](var value: Pipeline[I,V], var initial: I.StateType) raises V.Error -> V.Out where I.RunCompatible[V]:
    return value^.run(initial^)

def writer_run[I: WriterFamily, V: Movable & Deinitable](var value: Pipeline[I,V]) -> I.Unwrapped[V] where I.CarrierCompatible[V]:
    return value^.run()

comptime Inner = Reader[Int]
comptime Outer = ReaderT[Inner, List[Int]]

@fieldwise_init
struct Held[o: ImmOrigin](ReaderAction):
    var owner: Pointer[List[Int], Self.o]
    comptime Family = Inner
    comptime Env = Int
    comptime Value = Int
    comptime Out[q: ImmOrigin] = Int
    def run[q: ImmOrigin](deinit self, ref[q] env: Int) -> Int:
        return self.owner[][0] + env

@fieldwise_init
struct Retaining(ReaderAction):
    comptime Family = Outer
    comptime Env = List[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Held[o]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return Held[o](Pointer(to=env))

def fail(value: Int) raises Int -> Int: raise value

def reader_failure[o: ImmOrigin](ref[o] env: Int) raises:
    var caught = False
    try:
        _ = pipeline(FailRead()).raising[String]().run(env)
    except error:
        comptime assert type_of(error) == Pointer[Int, o]
        caught = error == Pointer(to=env)
    assert_equal(caught, True)

def main() raises:
    comptime R = Reader[Int]
    comptime S = State[Int]
    comptime W = Writer[StringMonoid]
    assert_equal(reader(pipeline(ask[R]()).map(twice), 3), 6)
    assert_equal(state(pipeline(get[S]()).map(twice), 3), (6,3))
    assert_equal(writer_run(pipeline(writer[W,Int]((String("log"),3)))), (String("log"),3))
    var calls = 0
    def counted(value: Int) {mut calls} -> Int:
        calls += 1
        return value + 1
    var pending = pipeline(asks[R](counted))
    assert_equal(calls, 0)
    assert_equal(pending^.run(4), 5)
    assert_equal(calls, 1)
    comptime WR = WriterT[R, StringMonoid]
    var layered = pipeline(WR.lift(asks[R](counted)))
    var base = layered^.run()
    assert_equal(calls, 1)
    var written = pipeline(base^).run(8)
    assert_equal(written[0], "")
    assert_equal(written[1], 9)
    assert_equal(calls, 2)
    # The callback error selection does not rewrite a recipe's execution error.
    var error_code = 0
    try:
        _ = pipeline(inspect[S](fail)).raising[String]().run(23)
    except error:
        comptime assert type_of(error) == Int
        error_code = error
    assert_equal(error_code, 23)
    var env = 11
    reader_failure(env)
    var owner: List[Int] = [19]
    var retained = pipeline(Retaining()).run(owner)
    comptime assert type_of(retained) == Held[origin_of(owner)]
    assert_equal(pipeline(retained^).run(4), 23)
