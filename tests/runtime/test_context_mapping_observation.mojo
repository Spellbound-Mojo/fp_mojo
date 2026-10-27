"""Mapping-only observation retains its family and native/deferred behavior."""
from fp.algebra import Functor, ErrorMapping, ApplicativeError, TapErrContract, ResultFamily, IdentityFamily
from fp.callables import BorrowCallContract
from fp.functions import pipeline, Pipeline
from fp.data import Result, Ok, Err
from fp.effects import ReaderT, StateT, WriterT, run
from context_error_capability_support import BorrowValue, BorrowEffect, observe
from error_mapping_support import Probe
from context_error_mapping_nonmonad_support import ToValidation
from context_recovery_admission_support import MissingBorrow
from context_layer_error_mapping_support import MappingMonad
from std.testing import assert_equal
from std.builtin.rebind import downcast

def combined[I:Functor,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var callback:C) raises TapErrContract[I,V,C].Error -> Pipeline[TapErrContract[I,V,C].Family,TapErrContract[I,V,C].Out] where TapErrContract[I,V,C].Compatible:
    return pipeline[I](source^).tap_err(callback^)

def components[I:Functor,V:Movable & Deinitable,C:BorrowCallContract & Movable & Deinitable](var source:V,var callback:C) raises TapErrContract[I,V,C].Error -> TapErrContract[I,V,C].Out where TapErrContract[I,V,C].CapabilityCompatible and TapErrContract[I,V,C].InputCompatible and TapErrContract[I,V,C].FamilyCompatible and TapErrContract[I,V,C].ReceiverCompatible and TapErrContract[I,V,C].NativeErrorsCompatible and TapErrContract[I,V,C].OperationCompatible:
    return combined[I](source^,callback^).get()

def native[A:Movable & Deinitable,E:Movable & Deinitable,R:Movable & Deinitable,X:Movable & Deinitable,o:ImmOrigin,//,F:def(E) raises X -> R](var source:Result[A,E],ref[o] callback:F) raises X -> Result[A,E]:
    return pipeline[Probe[E]](source^).raising[X]().tap_err(callback).get()

def main() raises:
    comptime I=Probe[String]
    comptime R=Result[Int,String]
    comptime assert TapErrContract[I,R,BorrowValue[String]].Compatible
    comptime assert not TapErrContract[Probe[String,1],R,BorrowValue[String]].Compatible
    comptime assert not TapErrContract[Probe[String,2],R,BorrowValue[String]].Compatible
    comptime assert TapErrContract[IdentityFamily,R,BorrowValue[String]].Compatible
    comptime assert not TapErrContract[I,R,BorrowValue[Int]].Compatible
    comptime assert not TapErrContract[I,R,MissingBorrow].Compatible
    comptime assert not TapErrContract[ToValidation,R,BorrowValue[String]].Compatible
    comptime assert not TapErrContract[IdentityFamily,Int,BorrowValue[Int]].Compatible
    var intrinsic=combined[IdentityFamily](R(Err(String("intrinsic"))),BorrowValue[String]())
    comptime assert type_of(intrinsic).I == ResultFamily[String]
    assert_equal(intrinsic^.get()._err().value,"intrinsic")
    assert_equal(pipeline[I](R(Err(String("native")))).tap_err(observe).get()._err().value,"native")
    assert_equal(native(R(Err(String("generic"))),observe)._err().value,"generic")
    assert_equal(components[I](R(Err(String("library"))),BorrowValue[String]())._err().value,"library")
    assert_equal(combined[I](R(Err(String("effect"))),BorrowEffect[String]()).get()._err().value,"effect")
    comptime D=ReaderT[MappingMonad[String],Int]
    var deferred=combined[D](D.lift(R(Err(String("deferred")))),BorrowValue[String]())
    comptime assert type_of(deferred).I == D
    assert_equal(run[D](deferred^.get(),0)._err().value,"deferred")
    comptime S=StateT[ResultFamily[String],Int]
    assert_equal(run[S](combined[S](S.fail[Int](String("AE")),BorrowValue[String]()).get(),0)._err().value,"AE")
