"""AttemptTapContract forwards combined and component proofs without private adapters."""
from fp.algebra import Functor,ApplicativeError,Monad,ResultFamily,IdentityFamily,AttemptTapContract
from fp.callables import BorrowCallContract,BorrowCallable
from fp.effects import Reader,ReaderT,ResultT,run
from fp.functions import pipeline,Pipeline
from fp.data import Result,Ok,Err
from std.builtin.rebind import downcast
from std.testing import assert_equal
from test_context_family_ensure import Family

def expanded[I:ApplicativeError & Monad,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises AttemptTapContract[I,V,C].Error -> AttemptTapContract[I,V,C].Out where C.Payload == Result[I.Element[V],I.Failure] and I._ErrorCarrier[V] and I._ErrorCarrier[C.Result] and AttemptTapContract[I,V,C].MaterializeMapCompatible and AttemptTapContract[I,V,C].MaterializeHandleCompatible and AttemptTapContract[I,V,C].ObserveBindCompatible and AttemptTapContract[I,V,C].RestoreBindCompatible:
    return pipeline[I](source^).attempt_tap(observer^).get()


def combined[I:ApplicativeError & Monad,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises AttemptTapContract[I,V,C].Error -> AttemptTapContract[I,V,C].Out where AttemptTapContract[I,V,C].Compatible:
    return expanded[I](source^,observer^)


def from_components[I:ApplicativeError & Monad,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises AttemptTapContract[I,V,C].Error -> AttemptTapContract[I,V,C].Out where C.Payload == Result[I.Element[V],I.Failure] and I._ErrorCarrier[V] and I._ErrorCarrier[C.Result] and AttemptTapContract[I,V,C].MaterializeMapCompatible and AttemptTapContract[I,V,C].MaterializeHandleCompatible and AttemptTapContract[I,V,C].ObserveBindCompatible and AttemptTapContract[I,V,C].RestoreBindCompatible:
    return combined[I](source^,observer^)

def witnessed[I:Functor,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises AttemptTapContract[downcast[I,ApplicativeError & Monad],V,C].Error -> AttemptTapContract[downcast[I,ApplicativeError & Monad],V,C].Out where conforms_to(I,ApplicativeError) and conforms_to(I,Monad) and AttemptTapContract[downcast[I,ApplicativeError & Monad],V,C].Compatible:
    return pipeline[I](source^).attempt_tap(observer^).get()


def continued[I:ApplicativeError & Monad,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises AttemptTapContract[I,V,C].Error -> Pipeline[AttemptTapContract[I,V,C].Family,AttemptTapContract[I,V,C].Out] where AttemptTapContract[I,V,C].Compatible:
    return pipeline[I](source^).attempt_tap(observer^)


@fieldwise_init
struct Observe[I:ApplicativeError](BorrowCallable):
    comptime Payload=Result[Int,Self.I.Failure]
    comptime Result=Self.I.Pure[NoneType]
    def invoke(self,ref outcome:Self.Payload) capturing -> Self.Result:return Self.I.pure(NoneType())


def generic[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable,o:ImmOrigin,//,F:def(Result[A,E]) raises X -> Result[R,E]](var source:Result[A,E],ref[o] observer:F) raises X -> Result[A,E]:
    return pipeline(source^).raising[X]().attempt_tap(observer).get()


def intrinsic[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable,o:ImmOrigin,//,I:Functor,F:def(Result[A,E]) raises X -> Result[R,E]](var source:Result[A,E],ref[o] observer:F) raises X -> Result[A,E] where not conforms_to(I,ApplicativeError):
    return pipeline[I](source^).raising[X]().attempt_tap(observer).get()


def thin[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable](var source:Result[A,E],observer:def(Result[A,E]) raises X thin ->Result[R,E]) raises X ->Result[A,E]:
    return pipeline(source^).raising[X]().attempt_tap(observer).get()


def main() raises:
    comptime F=ResultFamily[String]
    assert_equal(combined[F](F.pure(4),Observe[F]())._ok().value,4)
    assert_equal(from_components[F](F.fail[Int](String("old")),Observe[F]())._err().value,"old")
    assert_equal(witnessed[F](F.pure(5),Observe[F]())._ok().value,5)
    comptime R=Reader[Int]
    comptime I=ResultT[R,String]
    assert_equal(run[R](combined[I](I.pure(6),Observe[I]()),0)._ok().value,6)
    assert_equal(run[R](from_components[I](I.fail[Int](String("later")),Observe[I]()),0)._err().value,"later")
    comptime Conditional=ReaderT[F,Int]
    assert_equal(run[Conditional](witnessed[Conditional](Conditional.pure(7),Observe[Conditional]()),0)._ok().value,7)
    var fluent=continued[I](I.pure(8),Observe[I]())
    comptime assert type_of(fluent).I==I
    def double(var value:Int)->Int:return value*2
    assert_equal(run[R](fluent^.map(double).get(),0)._ok().value,16)
    comptime assert not AttemptTapContract[Family[False,False,False],Result[Int,String],Observe[Family[False,False,False]]].ObserveBindCompatible
    def accepted(outcome:Result[Int,String]) raises Never ->Result[NoneType,String]:return Ok(NoneType())
    assert_equal(generic(F.pure(9),accepted)._ok().value,9)
    assert_equal(intrinsic[IdentityFamily](F.fail[Int](String("intrinsic")),accepted)._err().value,"intrinsic")
    var pointer:def(Result[Int,String]) raises Never thin ->Result[NoneType,String]=accepted
    assert_equal(thin(F.pure(10),pointer)._ok().value,10)
    def raised(outcome:Result[Int,String]) raises Int ->Result[NoneType,String]:raise 752
    var code=0
    try:_ = generic(F.pure(1),raised)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,752)
    var raising:def(Result[Int,String]) raises Int thin ->Result[NoneType,String]=raised
    try:_ = thin(F.pure(1),raising)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,752)
