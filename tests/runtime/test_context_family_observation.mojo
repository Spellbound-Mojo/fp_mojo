"""Selected observation retains family policy, deferred timing and native errors."""
from fp.functions import pipeline
from fp.algebra import Applicative, ApplicativeError, ErrorMapping, ResultFamily, ListFamily, ValidationFamily, ListMonoid, IdentityFamily
from fp.algebra.contracts import TapErrContract, FlatTapErrContract
from fp.callables import BorrowCallContract, BorrowCallable, UnaryContract, BinaryContract, ThunkContract
from fp.effects import Reader, ReaderT, ResultT, run
from fp.data import Result, Ok, Err
from std.builtin.rebind import downcast
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_recovery_contracts import ConstructionFailure


def tapped[I: ApplicativeError,V: Movable & Deinitable,C: BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises TapErrContract[I,V,C].Error -> TapErrContract[I,V,C].Out where TapErrContract[I,V,C].Compatible:
    return pipeline[I](source^).tap_err(observer^).get()


def flat_tapped[I: ApplicativeError,V: Movable & Deinitable,C: BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises FlatTapErrContract[I,V,C].Error -> FlatTapErrContract[I,V,C].Out where FlatTapErrContract[I,V,C].Compatible:
    return pipeline[I](source^).flat_tap_err(observer^).get()


def conditional[I: Applicative,V: Movable & Deinitable,C: BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises TapErrContract[I,V,C].Error -> TapErrContract[I,V,C].Out where conforms_to(I,ApplicativeError) and TapErrContract[I,V,C].Compatible:
    return pipeline[I](source^).tap_err(observer^).get()


def conditional_witness[I: Applicative,V: Movable & Deinitable,C: BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises TapErrContract[downcast[I,ApplicativeError],V,C].Error -> TapErrContract[downcast[I,ApplicativeError],V,C].Out where conforms_to(I,ApplicativeError) and TapErrContract[downcast[I,ApplicativeError],V,C].Compatible:
    return pipeline[downcast[I,ApplicativeError]](source^).tap_err(observer^).get()


def conditional_flat[I: Applicative,V: Movable & Deinitable,C: BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises FlatTapErrContract[downcast[I,ApplicativeError],V,C].Error -> FlatTapErrContract[downcast[I,ApplicativeError],V,C].Out where conforms_to(I,ApplicativeError) and FlatTapErrContract[downcast[I,ApplicativeError],V,C].Compatible:
    return pipeline[I](source^).flat_tap_err(observer^).get()


@fieldwise_init
struct Inspect(BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload=String
    comptime Result=Int
    def invoke(self,ref error:String) capturing -> Int:
        self.calls[] += 1
        return error.byte_length()


@fieldwise_init
struct ObserveEffect[I: ApplicativeError](BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload=Self.I.Failure
    comptime Result=Self.I.Pure[String]
    def invoke(self,ref error:Self.Payload) capturing -> Self.Result:
        self.calls[] += 1
        return Self.I.pure(String("discarded"))


def eager() raises:
    comptime R=ResultFamily[String]
    var calls=ArcPointer(0)
    def effect(error:String) {calls} -> Result[Int,String]:
        calls[] += 1
        return Err(String("observer"))
    assert_equal(pipeline(R.fail[Int](String("original"))).tap_err(effect).get()._err().value,"original")
    assert_equal(pipeline(R.fail[Int](String("original"))).flat_tap_err(effect).get()._err().value,"observer")
    assert_equal(pipeline(R.pure(4)).tap_err(effect).flat_tap_err(effect).get()._ok().value,4)
    assert_equal(calls[],2)
    comptime V=ValidationFamily[ListMonoid[String]]
    def accumulate(errors:List[String]) -> V.Pure[NoneType]: return Err(List[String](["observer"]))
    var accumulated=pipeline[V](V.fail[Int](List[String](["original"]))).flat_tap_err(accumulate)
    comptime assert type_of(accumulated).I == V
    assert_equal(accumulated^.get()._err().value,List[String](["observer","original"]))
    comptime L=ResultT[ListFamily,String]
    def branches(error:String) -> List[Result[Int,String]]:
        if error == "empty": return List[Result[Int,String]]()
        return List[Result[Int,String]]([Result[Int,String](Ok(1)),Result[Int,String](Err(String("observer"))),Result[Int,String](Ok(2))])
    var values=List[Result[Int,String]]([Result[Int,String](Ok(8)),Result[Int,String](Err(String("original"))),Result[Int,String](Err(String("empty")))])
    var observed=pipeline[L](values^).flat_tap_err(branches)
    comptime assert type_of(observed).I == L
    var result=observed^.get()
    assert_equal(len(result),4)
    assert_equal(result[0]._ok().value,8)
    assert_equal(result[1]._err().value,"original")
    assert_equal(result[2]._err().value,"observer")
    assert_equal(result[3]._err().value,"original")
    assert_equal(pipeline[IdentityFamily](R.fail[Int](String("intrinsic"))).tap_err(effect).get()._err().value,"intrinsic")
    assert_equal(pipeline[IdentityFamily](R.fail[Int](String("intrinsic"))).flat_tap_err(effect).get()._err().value,"observer")


def deferred() raises:
    comptime R=Reader[Int]
    comptime I=ResultT[R,String]
    var calls=ArcPointer(0)
    def inspect(error:String) {calls}: calls[] += 1
    def effect(error:String) {calls} -> I.Pure[Int]:
        calls[] += 10
        return I.pure(0)
    var pending=pipeline[I](I.fail[Int](String("later"))).tap_err(inspect).flat_tap_err(effect)
    comptime assert type_of(pending).I == I
    assert_equal(calls[],0)
    assert_equal(run[R](pending^.get(),0)._err().value,"later")
    assert_equal(calls[],11)
    var skipped=pipeline[I](I.pure(3)).tap_err(inspect).flat_tap_err(effect).get()
    assert_equal(run[R](skipped^,0)._ok().value,3)
    assert_equal(calls[],11)
    var abandoned=pipeline[I](I.fail[Int](String("unused"))).tap_err(inspect).get()
    _ = abandoned^
    assert_equal(calls[],11)
    assert_equal(run[R](tapped[I](I.fail[Int](String("generic")),Inspect(calls)),0)._err().value,"generic")
    assert_equal(run[R](flat_tapped[I](I.fail[Int](String("generic")),ObserveEffect[I](calls)),0)._err().value,"generic")
    comptime Conditional=ReaderT[ResultFamily[String],Int]
    assert_equal(run[Conditional](conditional[Conditional](Conditional.fail[Int](String("conditional")),Inspect(calls)),0)._err().value,"conditional")
    assert_equal(run[Conditional](conditional_flat[Conditional](Conditional.fail[Int](String("conditional")),ObserveEffect[Conditional](calls)),0)._err().value,"conditional")
    assert_equal(run[Conditional](conditional_witness[Conditional](Conditional.fail[Int](String("witness")),Inspect(calls)),0)._err().value,"witness")
    assert_equal(calls[],16)
    def length(error:String) -> Int: return error.byte_length()
    var pointer:def(String) thin -> Int=length
    var stored=pipeline[I](I.fail[Int](String("pointer"))).tap_err(pointer).get()
    def zero(error:String) -> Int:return 0
    pointer=zero
    assert_equal(pointer(String("x")),0)
    assert_equal(run[R](stored^,0)._err().value,"pointer")
    def raised(error:String) raises Int -> Int:raise 701
    var raising=pipeline[I](I.fail[Int](String("raised"))).raising[Int]().tap_err(raised).get()
    var code=0
    try: _ = run[R](raising^,0)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,701)
    def flat_raised(error:String) raises Int -> I.Pure[NoneType]:raise 702
    var flat_raising=pipeline[I](I.fail[Int](String("raised"))).raising[Int]().flat_tap_err(flat_raised).get()
    try: _ = run[R](flat_raising^,0)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,702)


struct FailurePolicy(ApplicativeError,ErrorMapping):
    comptime Base=ResultFamily[String]
    comptime Element[V:Movable & Deinitable]=Self.Base.Element[V]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.Base.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.Base.MapError[V,F]
    comptime Pure[A:Movable & Deinitable]=Self.Base.Pure[A]
    comptime Combined[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable]=Self.Base.Combined[V,F,R]
    comptime CombineError[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable]=Int
    comptime Failure=String
    comptime Failed[A:Movable & Deinitable]=Self.Base.Failed[A]
    comptime FailError[A:Movable & Deinitable]=Int
    comptime Handled[V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable]=Self.Base.Handled[V,H]
    comptime HandleError[V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable]=H.Error
    comptime _ErrorCarrier[V:Movable & Deinitable]=Self.Base.CarrierCompatible[V]
    comptime ErrorCarrierCompatible[V:Movable & Deinitable]=Self.Base.ErrorCarrierCompatible[V]
    comptime DefaultErrorTarget[A:Movable & Deinitable,E:Movable & Deinitable]=ResultFamily[E]
    comptime BimapCompatible[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable]=Self.Base.BimapCompatible[ResultFamily[G.Out],V,F,G]
    comptime Bimapped[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable]=Self.Base.Bimapped[ResultFamily[G.Out],V,F,G]
    comptime BimapError[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable]=Int
    @staticmethod
    def bimap[Target:ErrorMapping,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,G:UnaryContract & Movable & Deinitable](var f:F,var g:G,var source:V) raises Int -> Self.Bimapped[Target,V,F,G]:raise 799
    @staticmethod
    def pure[A:Movable & Deinitable](var value:A)->Self.Pure[A]:return Self.Base.pure(value^)
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:return Self.Base.map(f^,value^)
    @staticmethod
    def map2_lazy[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](var f:F,var left:V,var right:R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]:
        raise 722
    @staticmethod
    def fail[A:Movable & Deinitable](var error:String) raises Self.FailError[A] -> Self.Failed[A]:
        raise 721
    @staticmethod
    def or_else[V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable](var handler:H,var source:V) raises H.Error -> Self.Handled[V,H]:return Self.Base.or_else(handler^,source^)


def custom() raises:
    var calls=ArcPointer(0)
    var code=0
    try: _ = pipeline[ConstructionFailure](Result[Int,String](Err(String("x")))).tap_err(Inspect(calls)).get()
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,709)
    assert_equal(calls[],0)
    try: _ = pipeline[ConstructionFailure](Result[Int,String](Err(String("x")))).flat_tap_err(ObserveEffect[ConstructionFailure](calls)).get()
    except error:code=error
    assert_equal(code,709)
    assert_equal(calls[],0)
    try: _ = pipeline[FailurePolicy](Result[Int,String](Err(String("x")))).tap_err(Inspect(calls)).get()
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,721)
    assert_equal(calls[],1)
    try: _ = pipeline[FailurePolicy](Result[Int,String](Err(String("x")))).flat_tap_err(ObserveEffect[FailurePolicy](calls)).get()
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,722)
    assert_equal(calls[],2)


def origins(input_owner:List[Int],output_owner:List[Int]) raises:
    comptime Stored=type_of(Span(input_owner))
    comptime Produced=type_of(Span(output_owner))
    comptime R=Reader[Int]
    comptime I=ResultT[R,Stored]
    def inspect(error:Stored) {ref output_owner} -> Produced:return Span(output_owner)
    def effect(error:Stored) {ref output_owner} -> I.Pure[Produced]:return I.pure(Span(output_owner))
    var pending=pipeline[I](I.fail[Int](Span(input_owner))).tap_err(inspect).flat_tap_err(effect).get()
    var result=run[R](pending^,0)
    assert_equal(result._err().value.unsafe_ptr()==Span(input_owner).unsafe_ptr(),True)
    def raised(error:Stored) raises Produced {ref output_owner} -> Int:raise Span(output_owner)
    var failing=pipeline[I](I.fail[Int](Span(input_owner))).raising[Produced]().tap_err(raised).get()
    var same=False
    try:_ = run[R](failing^,0)
    except error:
        comptime assert type_of(error)==Produced
        same=error.unsafe_ptr()==Span(output_owner).unsafe_ptr()
    assert_equal(same,True)


def main() raises:
    eager()
    deferred()
    custom()
    origins(List[Int]([1,2]),List[Int]([3,4]))
