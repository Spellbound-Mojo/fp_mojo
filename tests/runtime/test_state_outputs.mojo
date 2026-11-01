"""State terminals preserve base effects, generic proofs and exact native errors."""
from fp.effects import State, StateT, StateFamily, Reader, ResultT, RunValueContract, RunStateContract, run_value, run_state, run, asks, inspect, modify, put
from fp.functions import pipeline, Pipeline
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily
from fp.data import Result, Err
from algebra_support.external import PublicMonad
from std.testing import assert_equal


def value[I: StateFamily,V: Movable & Deinitable](var source: V,var initial: I.StateType) raises RunValueContract[I,V].Error -> RunValueContract[I,V].Out where RunValueContract[I,V].Compatible:
    return run_value[I](source^,initial^)


def final_state[I: StateFamily,V: Movable & Deinitable,E: Movable & Deinitable](var source: Pipeline[I,V,E],var initial: I.StateType) raises RunStateContract[I,V].Error -> RunStateContract[I,V].Out where RunStateContract[I,V].Compatible:
    return source^.run_state(initial^)


def ticket(value: Int) -> String: return "ticket " + String(value)
def increment(value: Int) -> Int: return value + 1
def fail(value: Int) raises Int -> String: raise value
def never(value: Int) raises Never -> Int: return value + 1
def native_void(value: Int): pass
def explicit_none(value: Int) -> NoneType: return None


def main() raises:
    comptime S = State[Int]
    assert_equal(value[S](inspect[S](ticket),10),"ticket 10")
    assert_equal(pipeline(inspect[S](ticket)).run_value(11),"ticket 11")
    assert_equal(final_state(pipeline(modify[S](increment)).raising[String](),10),11)
    assert_equal(run_state[S](put[S](12),10),12)
    assert_equal(pipeline(inspect[S](never)).run_value(10),11)
    var unit = run_value[S](inspect[S](native_void),10)
    comptime assert type_of(unit) == type_of(None)
    _ = unit
    assert_equal(pipeline(inspect[S](native_void)).run_state(10),10)
    var boxed = pipeline(inspect[S](explicit_none)).run_value(10)
    comptime assert type_of(boxed) == NoneType
    _ = boxed

    comptime O = StateT[OptionalFamily,Int]
    assert_equal(value[O](inspect[O](ticket),12).value(),"ticket 12")
    assert_equal(pipeline(put[O](13)).run_state(10).value(),13)
    assert_equal(Bool(run_value[O](O.lift(Optional[Int]()),10)),False)
    assert_equal(Bool(pipeline(O.lift(Optional[Int]())).run_state(10)),False)
    comptime R = StateT[ResultFamily[String],Int]
    assert_equal(value[R](inspect[R](ticket),14).get_or("failed"),"ticket 14")
    assert_equal(pipeline(put[R](15)).run_state(10).get_or(-1),15)
    assert_equal(run_value[R](R.lift(Result[Int,String](Err(String("stop")))),10).is_err(),True)
    assert_equal(pipeline(R.lift(Result[Int,String](Err(String("stop"))))).run_state(10).is_err(),True)
    comptime Layer = ResultT[S,String]
    assert_equal(run_value[S](Layer.fail[Int](String("stop")),10).is_err(),True)

    var calls = 0
    def counted(env: Int) {mut calls} -> Int:
        calls += 1
        return env + 1
    comptime D = StateT[Reader[Int],Int]
    var pending = pipeline(D.lift(asks[Reader[Int]](counted))).run_value(10)
    assert_equal(calls,0)
    assert_equal(pipeline(pending^).run(20),21)
    assert_equal(calls,1)

    for state_only in range(2):
        var error_code = 0
        try:
            if state_only: _ = pipeline(inspect[S](fail)).raising[String]().run_state(71)
            else: _ = pipeline(inspect[S](fail)).raising[String]().run_value(71)
        except error:
            comptime assert type_of(error) == Int
            error_code = error
        assert_equal(error_code,71)

    comptime F = StateT[PublicMonad[IdentityFamily,1],Int]
    for failing_recipe in range(2):
        var error_code = 0
        try:
            if failing_recipe: _ = value[F](inspect[F](fail),73)
            else: _ = value[F](F.pure(7),10)
        except error:
            comptime assert type_of(error) == Int
            error_code = error
        assert_equal(error_code,73 if failing_recipe else 702)
    var failed_state = 0
    try: _ = final_state(pipeline(F.pure(7)),10)
    except error: failed_state = error
    assert_equal(failed_state,702)
