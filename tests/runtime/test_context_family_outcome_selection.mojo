"""Custom Result storage keeps its family's outcome policy and map rebinding."""
from fp.algebra import ApplicativeError, Monad, RebindingFunctor, ResultFamily
from fp.callables import UnaryContract, BinaryContract, ThunkContract
from fp.functions import pipeline, RedeemContract
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_family_outcome_generic import Show, Explain, values
from test_context_recovery_contracts import ConstructionFailure


struct Rebound[A: Movable & Deinitable](ApplicativeError, RebindingFunctor):
    comptime Base = ResultFamily[String]
    comptime WithElement[T: Movable & Deinitable] = Rebound[T]
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    # Materialization maps through its original family. A later String map
    # verifies that the public selected output used WithElement[String].
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapCompatible[V,F] and (Self.A == String if F.Arg == String else True)
    comptime Pure[T: Movable & Deinitable] = Self.Base.Pure[T]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Failure = String
    comptime Failed[T: Movable & Deinitable] = Self.Base.Failed[T]
    comptime FailError[T: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.Handled[V,H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.HandleError[V,H]
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.Base.CarrierCompatible[V]
    @staticmethod
    def pure[T: Movable & Deinitable](var value: T) -> Self.Pure[T]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        comptime assert Self.MapCompatible[V,F]
        return Self.Base.map(function^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var function: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(function^,left^,right^)
    @staticmethod
    def fail[T: Movable & Deinitable](var error: String) -> Self.Failed[T]: return Self.Base.fail[T](error^)
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V,H] -> Self.Handled[V,H]: return Self.Base.or_else(handler^,source^)


struct ConstructionMonad(ApplicativeError, Monad):
    comptime Base = ResultFamily[String]
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Pure[A: Movable & Deinitable] = Self.Base.Pure[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Bound[V,F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.BindError[V,F]
    comptime Failure = String
    comptime Failed[A: Movable & Deinitable] = Self.Base.Failed[A]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.Handled[V,H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Int
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.Base.CarrierCompatible[V]
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]: return Self.Base.map(function^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var function: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(function^,left^,right^)
    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F, var value: V) raises Self.BindError[V,F] -> Self.Bound[V,F]: return Self.Base.flat_map(function^,value^)
    @staticmethod
    def fail[A: Movable & Deinitable](var error: String) -> Self.Failed[A]: return Self.Base.fail[A](error^)
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Int -> Self.Handled[V,H]: raise 929


def rebound() raises:
    comptime I = Rebound[Int]
    comptime V = Result[Int,String]
    comptime assert RedeemContract[I,V,Show,Explain].Family == Rebound[String]
    var selected = values[I](I.fail[Int](String("four")),Show(),Explain())
    comptime assert type_of(selected).I == Rebound[String]
    def length(var value: String) -> Int: return value.byte_length()
    var continued = selected^.map(length)
    comptime assert type_of(continued).I == Rebound[Int]
    assert_equal(continued^.get()._ok().value,4)


def custom_errors() raises:
    var calls = ArcPointer(0)
    def show(var value: Int) {calls} -> Int:
        calls[] += 1
        return value
    def explain(var error: String) {calls} -> Int:
        calls[] += 10
        return error.byte_length()
    var code = 0
    try: _ = pipeline[ConstructionFailure](Result[Int,String](Ok(1))).redeem(show,explain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,709)
    assert_equal(calls[],0)
    def success(var value: Int) {calls} -> Result[Int,String]:
        calls[] += 1
        return Ok(value)
    def failure(var error: String) {calls} -> Result[Int,String]:
        calls[] += 10
        return Ok(error.byte_length())
    code = 0
    try: _ = pipeline[ConstructionMonad](Result[Int,String](Err(String("old")))).redeem_with(success,failure).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,929)
    assert_equal(calls[],0)


def main() raises:
    rebound()
    custom_errors()
