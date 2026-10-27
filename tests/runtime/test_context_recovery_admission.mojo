"""Rejected family operations stay unprojected; exact valid calls still execute."""
from fp.algebra import RecoverContract, RecoverIfContract, OrElseIfContract, TapErrContract, FlatTapErrContract, ApplicativeError
from fp.callables import UnaryContract
from fp.functions import pipeline, piped, OrElseContract
from fp.data import Result, Ok, Err
from context_recovery_admission_support import Policy, MissingUnary, MissingBorrow, MissingEffect, RaiseBorrow, RaisePredicate
from context_error_capability_support import recover, effect, choose, observe, observe_effect, Value, Effect, Predicate, BorrowValue, BorrowEffect
from std.testing import assert_equal

def combined[I:ApplicativeError,V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable](var source:V,var handler:H) raises RecoverContract[I,V,H].Error->RecoverContract[I,V,H].Out where RecoverContract[I,V,H].Compatible:
    return pipeline[I](source^).recover(handler^).get()

def components[I:ApplicativeError,V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable](var source:V,var handler:H) raises RecoverContract[I,V,H].Error->RecoverContract[I,V,H].Out where RecoverContract[I,V,H].InputCompatible and RecoverContract[I,V,H].OutputCompatible and RecoverContract[I,V,H].CarrierCompatible and RecoverContract[I,V,H].ReceiverCompatible and RecoverContract[I,V,H].OperationCompatible:
    return combined[I](source^,handler^)

def legacy_expanded[I:ApplicativeError,V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable](var source:V,var handler:H) raises RecoverContract[I,V,H].Error->RecoverContract[I,V,H].Out where H.Arg==I.Failure and H.Out==I.Element[V] and I._ErrorCarrier[V]:
    return piped(source^).recover[I](handler^).get()

def main() raises:
    comptime R=Result[Int,String]
    comptime Blocked=Policy[False]
    comptime Allowed=Policy[True]
    comptime Throws=Policy[True,True]
    comptime assert not RecoverContract[Blocked,R,Value[String]].Compatible
    comptime assert not OrElseContract[Blocked,R,Effect[String,String]].Compatible
    comptime assert not RecoverIfContract[Blocked,R,Predicate[String],Value[String]].Compatible
    comptime assert not OrElseIfContract[Blocked,R,Predicate[String],Effect[String,String]].Compatible
    comptime assert not TapErrContract[Blocked,R,BorrowValue[String]].Compatible
    comptime assert not FlatTapErrContract[Policy[True,False,1],R,BorrowEffect[String]].Compatible
    comptime assert not FlatTapErrContract[Policy[True,False,2],R,BorrowEffect[String]].Compatible
    comptime assert not FlatTapErrContract[Blocked,R,BorrowEffect[String]].Compatible
    comptime assert not RecoverContract[Allowed,R,MissingUnary].ReceiverCompatible
    comptime assert not OrElseContract[Allowed,R,MissingEffect].ReceiverCompatible
    comptime assert not TapErrContract[Allowed,R,MissingBorrow].ReceiverCompatible
    comptime assert not TapErrContract[Throws,R,RaiseBorrow].NativeErrorsCompatible
    comptime assert not RecoverIfContract[Throws,R,RaisePredicate,Value[String]].NativeErrorsCompatible
    assert_equal(components[Allowed](R(Err(String("error"))),Value[String]())._ok().value,7)
    assert_equal(legacy_expanded[Allowed](R(Err(String("error"))),Value[String]())._ok().value,7)
    assert_equal(pipeline[Allowed](R(Err(String("error")))).recover(recover).get()._ok().value,5)
    assert_equal(pipeline[Allowed](R(Err(String("error")))).or_else(effect).get()._ok().value,5)
    assert_equal(pipeline[Allowed](R(Err(String("error")))).recover_if(choose,recover).get()._ok().value,5)
    assert_equal(pipeline[Allowed](R(Err(String("error")))).or_else_if(choose,effect).get()._ok().value,5)
    assert_equal(pipeline[Allowed](R(Err(String("error")))).tap_err(observe).get()._err().value,"error")
    assert_equal(pipeline[Allowed](R(Err(String("error")))).flat_tap_err(observe_effect).get()._err().value,"error")
    var code=0
    try:_=pipeline[Throws](R(Err(String("error")))).tap_err(observe).get()
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,771)
