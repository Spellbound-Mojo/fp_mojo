"""Native observers keep deferred calls, borrowed origins and exact errors."""
from fp.algebra import ApplicativeError, ErrorMapping, ResultFamily
from fp.effects import ReaderT, StateT, run
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from context_layer_error_mapping_support import MappingMonad
from error_mapping_support import Probe
from std.testing import assert_equal


def native_cases() raises:
    comptime R=Result[Int,String]
    comptime I=ReaderT[MappingMonad[String],Int]
    var calls=0
    def observer(error:String) {mut calls} -> Result[Int,String]:
        calls+=1
        return Err(String("discarded"))
    var pending=pipeline[I](I.lift(R(Err(String("original"))))).tap_err(observer)
    comptime assert type_of(pending).I == I
    assert_equal(calls,0)
    assert_equal(run[I](pending^.get(),0)._err().value,"original")
    assert_equal(calls,1)
    assert_equal(run[I](pipeline[I](I.pure(7)).tap_err(observer).get(),0)._ok().value,7)
    assert_equal(calls,1)
    _=pipeline[I](I.lift(R(Err(String("abandon"))))).tap_err(observer).get()
    assert_equal(calls,1)
    def raising(error:String) raises Int -> Int:raise 787
    def replacement(error:String) raises Int -> Int:raise 788
    var pointer:def(String) raises Int thin -> Int=raising
    var stored=pipeline[I](I.lift(R(Err(String("pointer"))))).raising[Int]().tap_err(pointer).get()
    pointer=replacement
    var code=0
    try:_=run[I](stored^,0)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,787)
    try:_=pointer(String("now"))
    except error:code=error
    assert_equal(code,788)
    # An underlying family can fail before invoking the observer.
    comptime F=ReaderT[MappingMonad[String,True],Int]
    var rejected=pipeline[F](F.pure(7)).tap_err(observer).get()
    try:_=run[F](rejected^,0)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,781)
    assert_equal(calls,1)


def origins(input_owner:List[Int],output_owner:List[Int]) raises:
    comptime Stored=type_of(Span(input_owner))
    comptime Produced=type_of(Span(output_owner))
    comptime I=ReaderT[MappingMonad[Stored],Int]
    def inspect(error:Stored) {ref output_owner}->Produced:return Span(output_owner)
    var pending=pipeline[I](I.lift(Result[Int,Stored](Err(Span(input_owner))))).tap_err(inspect).get()
    var kept=run[I](pending^,0)
    comptime assert type_of(kept)==Result[Int,Stored]
    assert_equal(kept._err().value.unsafe_ptr()==Span(input_owner).unsafe_ptr(),True)
    def fail(error:Stored) raises Produced {ref output_owner}->Int:raise Span(output_owner)
    var raised=pipeline[I](I.lift(Result[Int,Stored](Err(Span(input_owner))))).raising[Produced]().tap_err(fail).get()
    var same=False
    try:_=run[I](raised^,0)
    except error:
        comptime assert type_of(error)==Produced
        same=error.unsafe_ptr()==Span(output_owner).unsafe_ptr()
    assert_equal(same,True)
    def identity(error:Stored)->Stored:return error
    var pointer:def(Stored) thin->Stored=identity
    var eager=pipeline[Probe[Stored]](Result[Int,Stored](Err(Span(input_owner)))).tap_err(pointer).get()
    assert_equal(eager._err().value.unsafe_ptr()==Span(input_owner).unsafe_ptr(),True)


def main() raises:
    native_cases()
    origins(List[Int]([1,2]),List[Int]([3,4]))
