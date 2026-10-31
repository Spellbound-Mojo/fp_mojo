"""Selected recovery honors the family for native and deferred carriers."""
from fp.functions import pipeline, OrElseContract
from fp.algebra import Functor, Applicative, ApplicativeError, ResultFamily, ListFamily, IdentityFamily
from fp.algebra.contracts import RecoverContract
from fp.callables import Unary, UnaryContract
from fp.effects import Reader, ReaderT, ResultT, run
from fp.data import Result, Ok, Err
from std.builtin.rebind import downcast
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_recovery_contracts import Size, Raised, ConstructionFailure, Token, OwnedRestore, OwnedFailure, Stored


def recovered[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[I,V,H].Error -> RecoverContract[I,V,H].Out where RecoverContract[I,V,H].Compatible:
    return pipeline[I](source^).recover(handler^).get()


def replaced[I: Functor, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises OrElseContract[I,V,H].Error -> OrElseContract[I,V,H].Out where OrElseContract[I,V,H].Compatible:
    return pipeline[I](source^).or_else(handler^).get()


def conditional[I: Applicative, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[downcast[I,ApplicativeError],V,H].Error -> RecoverContract[downcast[I,ApplicativeError],V,H].Out where conforms_to(I,ApplicativeError) and RecoverContract[downcast[I,ApplicativeError],V,H].Compatible:
    return pipeline[I](source^).recover(handler^).get()


def length(var error: String) -> Int: return error.byte_length()


@fieldwise_init
struct Replacement[I: ApplicativeError](Unary):
    comptime Arg = Self.I.Failure
    comptime Out = Self.I.Pure[Int]
    def call(self, var error: Self.Arg) -> Self.Out: return Self.I.pure(12)


def deferred() raises:
    comptime R = Reader[Int]
    comptime T = ResultT[R,String]
    var calls = 0
    def restore(var error: String) {mut calls} -> Int:
        calls += 1
        return error.byte_length()
    var pending = pipeline[T](T.fail[Int](String("later"))).recover(restore)
    comptime assert type_of(pending).I == T
    assert_equal(calls,0)
    def double(var value: Int) -> Int: return value*2
    var mapped = pending^.map(double).get()
    assert_equal(calls,0)
    assert_equal(run[R](mapped^,0)._ok().value,10)
    assert_equal(calls,1)
    var skipped = pipeline[T](T.pure(8)).recover(restore).get()
    assert_equal(run[R](skipped^,0)._ok().value,8)
    assert_equal(calls,1)

    var pointer: def(var String) thin -> Int = length
    var owned_pointer = pipeline[T](T.fail[Int](String("four"))).recover(pointer).get()
    def zero(var error: String) -> Int: return 0
    pointer = zero
    assert_equal(pointer(String("x")),0)
    assert_equal(run[R](owned_pointer^,0)._ok().value,4)

    def effect(var error: String) {mut calls} -> T.Pure[Int]:
        calls += 1
        return T.pure(6)
    var replacement = pipeline[T](T.fail[Int](String("x"))).or_else(effect)
    comptime assert type_of(replacement).I == T
    assert_equal(calls,1)
    assert_equal(run[R](replacement^.map(double).get(),0)._ok().value,12)
    assert_equal(calls,2)

    var owned_calls = ArcPointer(0)
    assert_equal(run[R](recovered[T](T.fail[Int](String("generic")),Size(owned_calls)),0)._ok().value,7)
    assert_equal(run[R](replaced[T](T.fail[Int](String("effect")),Replacement[T]()),0)._ok().value,12)
    comptime C = ReaderT[ResultFamily[String],Int]
    assert_equal(run[C](conditional[C](C.fail[Int](String("conditional")),Size(owned_calls)),0)._ok().value,11)


def native_errors() raises:
    comptime R = Reader[Int]
    comptime T = ResultT[R,String]
    def raised(var error: String) raises Int -> Int: raise 701
    var pending = pipeline[T](T.fail[Int](String("x"))).raising[Int]().recover(raised).get()
    var code = 0
    try: _ = run[R](pending^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,701)
    var failed = pipeline[T](T.fail[Int](String("x"))).recover(Raised()).get()
    try: _ = run[R](failed^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,707)
    def effect(var error: String) raises Int -> T.Pure[Int]: raise 702
    var failed_effect = pipeline[T](T.fail[Int](String("x"))).raising[Int]().or_else(effect).get()
    try: _ = run[R](failed_effect^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,702)


def custom_family() raises:
    # Native Result storage must not bypass this family's construction failure.
    var calls = ArcPointer(0)
    var code = 0
    try:
        _ = pipeline[ConstructionFailure](Result[Int,String](Err(String("x")))).recover(Size(calls)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,709)
    assert_equal(calls[],0)
    code = 0
    try:
        _ = pipeline[ConstructionFailure](Result[Int,String](Err(String("x")))).or_else(Replacement[ConstructionFailure]()).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,709)


def owned[success: Bool]() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = I.pure(Token(2,drops)) if success else I.fail[Token](Token(2,drops))
    var restored = pipeline[I](source^).recover(OwnedRestore(Token(1,drops),calls))
    comptime assert type_of(restored).I == I
    var pending = restored^.get()
    assert_equal(drops[],0)
    var result = run[R](pending^,0)
    assert_equal(calls[],0 if success else 1)
    assert_equal(drops[],1)
    assert_equal(result._ok().value.value,2)
    _ = result^
    assert_equal(drops[],2)


def owned_failure() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var code = 0
    var pending = pipeline[I](I.fail[Token](Token(2,drops))).recover(OwnedFailure(Token(1,drops),calls)).get()
    assert_equal(drops[],0)
    try: _ = run[R](pending^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,711)
    assert_equal(calls[],1)
    assert_equal(drops[],2)


def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime R = Reader[Int]
    comptime I = ResultT[R,View]
    var pending = pipeline[I](I.fail[View](Span(owner))).recover(Stored[View]()).get()
    var restored = run[R](pending^,0)
    comptime assert type_of(restored) == Result[View,View]
    assert_equal(restored._ok().value.unsafe_ptr() == Span(owner).unsafe_ptr(),True)


def branches_and_result() raises:
    comptime I = ResultT[ListFamily,String]
    var calls = ArcPointer(0)
    var values = List[Result[Int,String]]([Result[Int,String](Err(String("a"))),Result[Int,String](Ok(9)),Result[Int,String](Err(String("three")))])
    var restored = pipeline[I](values^).recover(Size(calls))
    comptime assert type_of(restored).I == I
    var result = restored^.get()
    assert_equal(calls[],2)
    assert_equal(result[0]._ok().value,1)
    assert_equal(result[1]._ok().value,9)
    assert_equal(result[2]._ok().value,5)
    def changed(var error: String) -> Result[Int,Int]: return Ok(7)
    var different = pipeline(Result[Int,String](Err(String("x")))).or_else(changed)
    comptime assert type_of(different).I == ResultFamily[Int]
    assert_equal(different^.get()._ok().value,7)
    var intrinsic = pipeline[IdentityFamily](Result[Int,String](Err(String("x")))).recover(length)
    comptime assert type_of(intrinsic).I == ResultFamily[String]
    assert_equal(intrinsic^.get()._ok().value,1)
    var intrinsic_effect = pipeline[IdentityFamily](Result[Int,String](Err(String("x")))).or_else(changed)
    comptime assert type_of(intrinsic_effect).I == ResultFamily[Int]
    assert_equal(intrinsic_effect^.get()._ok().value,7)
    assert_equal(replaced[ResultFamily[String]](Result[Int,String](Err(String("x"))),Replacement[ResultFamily[String]]())._ok().value,12)


def recover_native[A: Movable & Deinitable, Stored: Movable & Deinitable, X: Movable & Deinitable, o: ImmOrigin, F: def(var Stored) raises X -> A](var value: Result[A,Stored], ref[o] handler:F) raises X -> Result[A,Stored]:
    return pipeline(value^).raising[X]().recover(handler).get()

def effect_native[A: Movable & Deinitable, Stored: Movable & Deinitable, X: Movable & Deinitable, o: ImmOrigin, F: def(var Stored) raises X -> Result[A,Stored]](var value: Result[A,Stored], ref[o] handler:F) raises X -> Result[A,Stored]:
    return pipeline(value^).raising[X]().or_else(handler).get()

def changed_native[A: Movable & Deinitable, Stored: Movable & Deinitable, X: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, F: def(var Stored) raises X -> Result[A,E]](var value: Result[A,Stored], ref[o] handler:F) raises X -> Result[A,E]:
    return pipeline(value^).raising[X]().or_else(handler).get()


def main() raises:
    deferred()
    native_errors()
    custom_family()
    owned[False]()
    owned[True]()
    owned_failure()
    origins(List[Int]([1,2]))
    branches_and_result()
    comptime assert not OrElseContract[ResultFamily[String],Result[Int,String],Size].OutputCompatible
    comptime assert not OrElseContract[IdentityFamily,Int,Size].Compatible
    def restore(var error:String) raises Never -> Int: return error.byte_length()
    assert_equal(recover_native(Result[Int,String](Err(String("x"))),restore)._ok().value,1)
    def effect(var error:String) raises Never -> Result[Int,String]: return Ok(error.byte_length())
    assert_equal(effect_native(Result[Int,String](Err(String("x"))),effect)._ok().value,1)
    def changed(var error:String) raises Never -> Result[Int,Int]: return Ok(error.byte_length())
    assert_equal(changed_native(Result[Int,String](Err(String("x"))),changed)._ok().value,1)
