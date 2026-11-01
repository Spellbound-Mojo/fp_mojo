"""Unmatched errors use family.fail; its native error stays distinct from storage."""
from fp.algebra import ApplicativeError, ResultFamily
from fp.algebra.contracts import RecoverIfContract, OrElseIfContract
from fp.callables import UnaryContract, BinaryContract, ThunkContract
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_family_conditional_generic import Match, Length
from test_context_recovery_contracts import Raised


struct FailingReintroduction(ApplicativeError):
    comptime Base = ResultFamily[String]
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Pure[A: Movable & Deinitable] = Self.Base.Pure[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Failure = String
    comptime Failed[A: Movable & Deinitable] = Self.Base.Failed[A]
    comptime FailError[A: Movable & Deinitable] = Int
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.Handled[V,H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = H.Error
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.Base.CarrierCompatible[V]
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]: return Self.Base.map(function^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var function: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(function^,left^,right^)
    @staticmethod
    def fail[A: Movable & Deinitable](var error: String) raises Int -> Self.Failed[A]: raise 841
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V,H] -> Self.Handled[V,H]: return Self.Base.or_else(handler^,source^)


def native_errors() raises:
    comptime I = FailingReintroduction
    comptime V = Result[Int,String]
    comptime assert RecoverIfContract[I,V,Match,Length].Error == Int
    var calls = ArcPointer(0)
    def reject(error: String) {calls} -> Bool:
        calls[] += 1
        return False
    def accept(error: String) {calls} -> Bool:
        calls[] += 1
        return True
    def handler(var error: String) {calls} -> Int:
        calls[] += 10
        return 9
    var code = 0
    try: _ = pipeline[I](V(Err(String("keep")))).recover_if(reject,handler).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,841)
    assert_equal(calls[],1)
    var restored: V
    try: restored = pipeline[I](V(Err(String("retry")))).recover_if(accept,handler).get()
    except _: raise Error("matching recovery must not call fail")
    assert_equal(restored._ok().value,9)
    assert_equal(calls[],12)
    try: restored = pipeline[I](V(Ok(2))).recover_if(reject,handler).get()
    except _: raise Error("successful source must skip conditional recovery")
    assert_equal(restored._ok().value,2)
    assert_equal(calls[],12)
    def effect(var error: String) {calls} -> V:
        calls[] += 10
        return Ok(7)
    code = 0
    try: _ = pipeline[I](V(Err(String("keep")))).or_else_if(reject,effect).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,841)
    assert_equal(calls[],13)
    def failed_predicate(error: String) raises Int {calls} -> Bool:
        calls[] += 1
        raise 842
    try: _ = pipeline[I](V(Err(String("retry")))).raising[Int]().recover_if(failed_predicate,handler).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,842)
    assert_equal(calls[],14)
    def failed_handler(var error: String) raises Int {calls} -> Int:
        calls[] += 10
        raise 843
    try: _ = pipeline[I](V(Err(String("retry")))).raising[Int]().recover_if(accept,failed_handler).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,843)
    assert_equal(calls[],25)


def deferred_errors() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    comptime assert RecoverIfContract[I,I.Failed[Int],Match,Raised].Error == Never
    var pending = pipeline[I](I.fail[Int](String("retry"))).recover_if(Match(),Raised()).get()
    var code = 0
    try: _ = run[R](pending^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,707)
    def predicate(error: String) raises Int -> Bool: raise 844
    def handler(var error: String) -> Int: return 3
    var failed = pipeline[I](I.fail[Int](String("retry"))).raising[Int]().recover_if(predicate,handler).get()
    try: _ = run[R](failed^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,844)


def main() raises:
    native_errors()
    deferred_errors()
