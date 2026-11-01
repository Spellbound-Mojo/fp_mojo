"""Selected conditional recovery preserves family timing, branches and capabilities."""
from fp.algebra import ApplicativeError, Monad, ResultFamily, ListFamily, IdentityFamily, ValidationFamily, ListMonoid
from fp.algebra.contracts import RecoverIfContract
from fp.effects import Reader, ReaderT, ResultT, run
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_family_conditional_generic import Match, Length, recovered, replaced
from test_context_recovery_contracts import Size, ConstructionFailure
from test_context_family_recovery import Replacement


def immediate() raises:
    var calls = ArcPointer(0)
    def predicate(error: String) {calls} -> Bool:
        calls[] += 1
        return error == "retry"
    def handler(var error: String) {calls} -> Int:
        calls[] += 10
        return 9
    comptime I = ResultT[IdentityFamily,String]
    var kept = pipeline[I](I.fail[Int](String("keep"))).recover_if(predicate,handler)
    comptime assert type_of(kept).I == I
    assert_equal(kept^.get()._err().value,"keep")
    assert_equal(calls[],1)
    assert_equal(pipeline[I](I.pure(2)).recover_if(predicate,handler).get()._ok().value,2)
    assert_equal(calls[],1)
    assert_equal(pipeline[I](I.fail[Int](String("retry"))).recover_if(predicate,handler).get()._ok().value,9)
    assert_equal(calls[],12)
    # Mixed native/library callbacks use the same family continuation.
    assert_equal(pipeline[I](I.fail[Int](String("retry"))).recover_if(Match(),handler).get()._ok().value,9)
    assert_equal(pipeline[I](I.fail[Int](String("retry"))).recover_if(predicate,Size(calls)).get()._ok().value,5)
    assert_equal(calls[],24)
    # Proven non-error families retain intrinsic Result behavior.
    var intrinsic = pipeline[IdentityFamily](Result[Int,String](Err(String("retry")))).recover_if(predicate,handler)
    comptime assert type_of(intrinsic).I == ResultFamily[String]
    assert_equal(intrinsic^.get()._ok().value,9)


def branches() raises:
    comptime I = ResultT[ListFamily,String]
    comptime R = Result[Int,String]
    var calls = ArcPointer(0)
    def predicate(error: String) {calls} -> Bool:
        calls[] += 1
        return error == "retry"
    def branch(var error: String) {calls} -> List[R]:
        calls[] += 10
        return List[R]([R(Ok(4)),R(Err(String("replacement")))])
    var source = List[R]([R(Err(String("keep"))),R(Ok(3)),R(Err(String("retry")))])
    var result = pipeline[I](source^).or_else_if(predicate,branch).get()
    assert_equal(calls[],12)
    assert_equal(len(result),4)
    assert_equal(result[0]._err().value,"keep")
    assert_equal(result[1]._ok().value,3)
    assert_equal(result[2]._ok().value,4)
    assert_equal(result[3]._err().value,"replacement")
    assert_equal(len(pipeline[I](List[R]()).or_else_if(predicate,branch).get()),0)
    assert_equal(calls[],12)


def deferred() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var calls = ArcPointer(0)
    def predicate(error: String) {calls} -> Bool:
        calls[] += 1
        return error == "retry"
    def handler(var error: String) {calls} -> Int:
        calls[] += 10
        return 11
    var pending = pipeline[I](I.fail[Int](String("retry"))).recover_if(predicate,handler)
    comptime assert type_of(pending).I == I
    assert_equal(calls[],0)
    def double(var value: Int) -> Int: return value*2
    var mapped = pending^.map(double).get()
    assert_equal(calls[],0)
    assert_equal(run[R](mapped^,0)._ok().value,22)
    assert_equal(calls[],11)
    var kept = pipeline[I](I.fail[Int](String("keep"))).or_else_if(predicate,Replacement[I]()).get()
    assert_equal(calls[],11)
    assert_equal(run[R](kept^,0)._err().value,"keep")
    assert_equal(calls[],12)
    var skipped = pipeline[I](I.pure(2)).recover_if(predicate,handler).get()
    assert_equal(run[R](skipped^,0)._ok().value,2)
    assert_equal(calls[],12)
    assert_equal(run[R](recovered[I](I.fail[Int](String("retry")),Match(),Length()),0)._ok().value,5)
    assert_equal(run[R](replaced[I](I.fail[Int](String("retry")),Match(),Replacement[I]()),0)._ok().value,12)
    comptime C = ReaderT[ResultFamily[String],Int]
    var conditional = pipeline[C](C.fail[Int](String("retry"))).recover_if(predicate,handler).get()
    assert_equal(run[C](conditional^,0)._ok().value,11)


def applicative_only() raises:
    comptime I = ValidationFamily[ListMonoid[String]]
    comptime assert not conforms_to(I,Monad)
    def multiple(errors: List[String]) -> Bool: return len(errors) > 1
    def count(var errors: List[String]) -> Int: return len(errors)
    var recovered = pipeline[I](I.fail[Int](List[String](["a","b"]))).recover_if(multiple,count)
    comptime assert type_of(recovered).I == I
    assert_equal(recovered^.get()._ok().value,2)
    assert_equal(pipeline[I](I.fail[Int](List[String](["one"]))).recover_if(multiple,count).get()._err().value[0],"one")
    def effect(var errors: List[String]) -> I.Pure[Int]: return I.pure(len(errors))
    assert_equal(pipeline[I](I.fail[Int](List[String](["a","b"]))).or_else_if(multiple,effect).get()._ok().value,2)


def construction_failure() raises:
    var calls = ArcPointer(0)
    def predicate(error: String) {calls} -> Bool:
        calls[] += 1
        return True
    var code = 0
    try: _ = pipeline[ConstructionFailure](Result[Int,String](Err(String("retry")))).recover_if(predicate,Size(calls)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,709)
    assert_equal(calls[],0)
    code = 0
    try: _ = pipeline[ConstructionFailure](Result[Int,String](Err(String("retry")))).or_else_if(predicate,Replacement[ConstructionFailure]()).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,709)
    assert_equal(calls[],0)


def main() raises:
    immediate()
    branches()
    deferred()
    applicative_only()
    construction_failure()
