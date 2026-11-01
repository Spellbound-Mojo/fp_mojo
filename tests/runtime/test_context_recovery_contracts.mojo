"""Generic recovery names one public contract and preserves family semantics."""
from fp.algebra import Applicative, ApplicativeError, ResultFamily, ListFamily
from fp.algebra.contracts import RecoverContract
from fp.functions import pipeline, Pipeline, Identity
from fp.callables import UnaryContract, Unary, OnceUnary, BinaryContract, ThunkContract
from fp.effects import Reader, ReaderT, ResultT, run
from std.builtin.rebind import downcast
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer

def expanded[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[I,V,H].Error -> RecoverContract[I,V,H].Out where H.Arg == I.Failure and H.Out == I.Element[V] and I._ErrorCarrier[V] and RecoverContract[I,V,H].ReceiverCompatible and RecoverContract[I,V,H].OperationCompatible:
    return recovered[I](source^, handler^)

def recovered[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[I,V,H].Error -> RecoverContract[I,V,H].Out where RecoverContract[I,V,H].Compatible:
    return pipeline[I](source^).recover(handler^).get()

@fieldwise_init
struct Size(Unary):
    var calls: ArcPointer[Int]
    comptime Arg = String
    comptime Out = Int
    def call(self, var value: String) -> Int:
        self.calls[] += 1
        return value.byte_length()

@fieldwise_init
struct Raised(Unary):
    comptime Arg = String
    comptime Out = Int
    comptime Error = Int
    def call(self, var value: String) raises Int -> Int: raise 707

def main() raises:
    var calls = ArcPointer(0)
    custom_family()
    family_projection()
    conditional_witness()
    owning_failure()
    owning_case[False]()
    owning_case[True]()
    origins(List[Int]([1, 2]))
    assert_equal(expanded[ResultFamily[String]](Result[Int,String](Err(String("old"))), Size(calls))._ok().value, 3)
    calls[] = 0
    comptime M = ResultFamily[String]
    var result = recovered[M](Result[Int,String](Err(String("four"))), Size(calls))
    assert_equal(result._ok().value, 4)
    assert_equal(calls[], 1)
    var skipped = recovered[M](Result[Int,String](Ok(9)), Size(calls))
    assert_equal(skipped._ok().value, 9)
    assert_equal(calls[], 1)
    comptime R = Reader[Int]
    comptime T = ResultT[R, String]
    var deferred = recovered[T](T.fail[Int](String("three")), Size(calls))
    assert_equal(calls[], 1)
    assert_equal(run[R](deferred^, 0)._ok().value, 5)
    assert_equal(calls[], 2)
    comptime assert RecoverContract[T,T.Failed[Int],Raised].Error == Never
    comptime assert RecoverContract[M,Result[Int,String],Raised].Error == Int
    var failed = recovered[T](T.fail[Int](String("x")), Raised())
    var code = 0
    try: _ = run[R](failed^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 707)
    comptime L = ResultT[ListFamily,String]
    var branched = recovered[L](List[Result[Int,String]]([Result[Int,String](Err(String("one"))),Result[Int,String](Err(String("two")))]), Size(calls))
    assert_equal(len(branched), 2)
    assert_equal(calls[], 4)


struct ConstructionFailure(ApplicativeError):
    comptime Base = ResultFamily[String]
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Pure[A: Movable & Deinitable] = Self.Base.Pure[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Failure = String
    comptime Failed[A: Movable & Deinitable] = Self.Base.Failed[A]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Self.Base.Handled[V,H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Int
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.Base.CarrierCompatible[V]
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]: return Self.Base.map(f^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(f^,left^,right^)
    @staticmethod
    def fail[A: Movable & Deinitable](var error: String) -> Self.Failed[A]: return Self.Base.fail[A](error^)
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Int -> Self.Handled[V,H]: raise 709

def custom_family() raises:
    var calls = ArcPointer(0)
    var code = 0
    try: _ = recovered[ConstructionFailure](Result[Int,String](Err(String("x"))), Size(calls))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 709)
    assert_equal(calls[],0)

@fieldwise_init
struct Stored[T: Movable & Deinitable](OnceUnary):
    comptime Arg = Self.T
    comptime Out = Self.T
    def call_once(deinit self, var value: Self.T) -> Self.T: return value^

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var value = Result[View,View](Err(Span(owner)))
    var restored = recovered[ResultFamily[View]](value^, Stored[View]())
    comptime assert type_of(restored) == Result[View,View]
    assert_equal(restored._ok().value.unsafe_ptr() == Span(owner).unsafe_ptr(), True)


@fieldwise_init
struct Token(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct OwnedRestore(OnceUnary):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Arg = Token
    comptime Out = Token
    def call_once(deinit self, var value: Token) -> Token:
        self.calls[] += 1
        return value^

def owning_case[success: Bool]() raises:
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source: Result[Token,Token]
    comptime if success: source = Ok(Token(2,drops))
    else: source = Err(Token(2,drops))
    var result = recovered[ResultFamily[Token]](source^, OwnedRestore(Token(1,drops), calls))
    assert_equal(calls[],0 if success else 1)
    assert_equal(drops[],1)
    assert_equal(result._ok().value.value,2)
    _ = result^
    assert_equal(drops[],2)


def recovered_pipeline[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[I,V,H].Error -> Pipeline[RecoverContract[I,V,H].Family, RecoverContract[I,V,H].Out] where RecoverContract[I,V,H].Compatible:
    return Pipeline[RecoverContract[I,V,H].Family, RecoverContract[I,V,H].Out](recovered[I](source^,handler^))

def family_projection() raises:
    var calls = ArcPointer(0)
    comptime I = ResultFamily[String]
    var immediate = recovered_pipeline[I](I.fail[Int](String("four")),Size(calls))
    comptime assert type_of(immediate).I == I
    assert_equal(immediate^.map(Identity[Int]()).get()._ok().value,4)
    assert_equal(calls[],1)
    calls[] = 0
    comptime R = Reader[Int]
    comptime T = ResultT[R,String]
    var deferred = recovered_pipeline[T](T.fail[Int](String("later")),Size(calls))
    comptime assert type_of(deferred).I == T
    var mapped = deferred^.map(Identity[Int]()).get()
    assert_equal(calls[],0)
    assert_equal(run[R](mapped^,0)._ok().value,5)
    assert_equal(calls[],1)

@fieldwise_init
struct OwnedFailure(OnceUnary):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Int
    def call_once(deinit self, var value: Token) raises Int -> Token:
        self.calls[] += 1
        raise 711

def owning_failure() raises:
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = Result[Token,Token](Err(Token(2,drops)))
    var code = 0
    try: _ = recovered[ResultFamily[Token]](source^, OwnedFailure(Token(1,drops),calls))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,711)
    assert_equal(calls[],1)
    assert_equal(drops[],2)


def recovered_conditional[I: Applicative, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[downcast[I,ApplicativeError],V,H].Error -> RecoverContract[downcast[I,ApplicativeError],V,H].Out where conforms_to(I,ApplicativeError) and RecoverContract[downcast[I,ApplicativeError],V,H].Compatible:
    # Use the same public witness for the metadata and the operation's adapter.
    return pipeline[downcast[I,ApplicativeError]](source^).recover(handler^).get()

def conditional_witness() raises:
    comptime I = ReaderT[ResultFamily[String],Int]
    var calls = ArcPointer(0)
    var pending = recovered_conditional[I](I.fail[Int](String("four")),Size(calls))
    assert_equal(calls[],0)
    assert_equal(run[I](pending^,0)._ok().value,4)
    assert_equal(calls[],1)
