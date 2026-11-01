"""Only the original selected outcome chooses a handler across effect families."""
from fp.algebra import ResultFamily, ListFamily, ValidationFamily, ListMonoid, Monad
from fp.effects import Reader, ReaderT, ResultT, OptionalT, run
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal


def branching() raises:
    comptime I = ResultT[ListFamily,String]
    comptime V = Result[Int,String]
    var calls = ArcPointer(0)
    def success(var value: Int) {calls} -> List[V]:
        calls[] += 1
        return List[V]([V(Err(String("handler"))),V(Ok(value+1))])
    def failure(var error: String) {calls} -> List[V]:
        calls[] += 10
        return List[V]([V(Ok(error.byte_length()))])
    var selected = pipeline[I](List[V]([V(Ok(2)),V(Err(String("four")))])).redeem_with(success,failure)
    comptime assert type_of(selected).I == I
    var result = selected^.get()
    assert_equal(calls[],11)
    assert_equal(len(result),3)
    assert_equal(result[0]._err().value,"handler")
    assert_equal(result[1]._ok().value,3)
    assert_equal(result[2]._ok().value,4)
    assert_equal(len(pipeline[I](List[V]()).redeem_with(success,failure).get()),0)
    assert_equal(calls[],11)
    comptime N = ResultT[ResultFamily[String],String]
    def show(var value: Int) {calls} -> String:
        calls[] += 1
        return String(value)
    def explain(var error: String) {calls} -> String:
        calls[] += 10
        return error^
    var outer = Result[V,String](Err(String("outer")))
    assert_equal(pipeline[N](outer^).redeem(show,explain).get()._err().value,"outer")
    assert_equal(calls[],11)
    comptime O = OptionalT[ResultFamily[String]]
    var absent = O.Pure[Int](Ok(Optional[Int]()))
    assert_equal(Bool(pipeline[O](absent^).redeem(show,explain).get()._ok().value),False)
    assert_equal(calls[],11)


def deferred() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var calls = ArcPointer(0)
    def success(var value: Int) {calls} -> I.Pure[Int]:
        calls[] += 1
        return I.fail[Int](String("handler"))
    def failure(var error: String) {calls} -> I.Pure[Int]:
        calls[] += 10
        return I.pure(8)
    var pending = pipeline[I](I.pure(2)).redeem_with(success,failure).get()
    assert_equal(calls[],0)
    assert_equal(run[R](pending^,0)._err().value,"handler")
    assert_equal(calls[],1)
    var restored = pipeline[I](I.fail[Int](String("old"))).redeem_with(success,failure).get()
    assert_equal(calls[],1)
    assert_equal(run[R](restored^,0)._ok().value,8)
    assert_equal(calls[],11)
    # ReaderT exposes distinct success/failure action types to the two handlers.
    comptime D = ReaderT[ResultFamily[String],Int]
    def direct(var value: Int) -> D.Pure[Int]: return D.pure(value+1)
    def retained(var error: String) -> D.Failed[Int]: return D.fail[Int](error^)
    var distinct = pipeline[D](D.fail[Int](String("kept"))).redeem_with(direct,retained).get()
    assert_equal(run[D](distinct^,0)._err().value,"kept")


def native_failure() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var calls = ArcPointer(0)
    def success(var value: Int) raises Int {calls} -> Int:
        calls[] += 1
        raise 921
    def failure(var error: String) raises Int {calls} -> Int:
        calls[] += 10
        raise 922
    var pending = pipeline[I](I.pure(2)).raising[Int]().redeem(success,failure).get()
    assert_equal(calls[],0)
    var code = 0
    try: _ = run[R](pending^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,921)
    assert_equal(calls[],1)
    var failed = pipeline[I](I.fail[Int](String("old"))).raising[Int]().redeem(success,failure).get()
    code = 0
    try: _ = run[R](failed^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,922)
    assert_equal(calls[],11)


def pointers() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    def original(var value: Int) -> String: return "saved"
    def changed(var value: Int) -> String: return "changed"
    def explain(var error: String) -> String: return error^
    var function: def(var Int) thin -> String = original
    var pending = pipeline[I](I.pure(2)).redeem(function,explain).get()
    function = changed
    assert_equal(function(2),"changed")
    assert_equal(run[R](pending^,0)._ok().value,"saved")


def validation() raises:
    comptime I = ValidationFamily[ListMonoid[String]]
    comptime assert not conforms_to(I,Monad)
    def show(var value: Int) -> String: return String(value)
    def errors(var failures: List[String]) -> String: return failures[0].copy()
    var selected = pipeline[I](I.fail[Int](List[String](["validation"]))).redeem(show,errors)
    comptime assert type_of(selected).I == I
    assert_equal(selected^.get()._ok().value,"validation")


def main() raises:
    branching()
    deferred()
    native_failure()
    pointers()
    validation()
