"""Conditional predicates borrow; selected handlers consume move-only errors once."""
from fp.algebra import IdentityFamily
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowCallable, BorrowOnceCallable, OnceUnary
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_recovery_contracts import Token, OwnedRestore, OwnedFailure, Stored


@fieldwise_init
struct OwnedPredicate(BorrowOnceCallable):
    var capture: Token
    var calls: ArcPointer[Int]
    var accept: Bool
    comptime Payload = Token
    comptime Result = Bool
    def invoke_once(deinit self, value: Token) -> Bool:
        self.calls[] += 1
        return self.accept


@fieldwise_init
struct FailedPredicate(BorrowOnceCallable):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Payload = Token
    comptime Result = Bool
    comptime Failure = Int
    def invoke_once(deinit self, value: Token) raises Int -> Bool:
        self.calls[] += 1
        raise 845


@fieldwise_init
struct OwnedEffect(OnceUnary):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Arg = Token
    comptime Out = Result[Token,Token]
    def call_once(deinit self, var value: Token) -> Self.Out:
        self.calls[] += 10
        return Ok(value^)


def values[success: Bool, accept: Bool]() raises:
    comptime I = ResultT[IdentityFamily,Token]
    var drops = ArcPointer(0)
    var predicates = ArcPointer(0)
    var handlers = ArcPointer(0)
    var source = I.pure(Token(2,drops)) if success else I.fail[Token](Token(2,drops))
    var result = pipeline[I](source^).recover_if(OwnedPredicate(Token(1,drops),predicates,accept),OwnedRestore(Token(3,drops),handlers)).get()
    assert_equal(predicates[],0 if success else 1)
    assert_equal(handlers[],1 if not success and accept else 0)
    assert_equal(drops[],2)
    comptime if success or accept: assert_equal(result._ok().value.value,2)
    else: assert_equal(result._err().value.value,2)
    _ = result^
    assert_equal(drops[],3)


def effects[accept: Bool]() raises:
    comptime I = ResultT[IdentityFamily,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var result = pipeline[I](I.fail[Token](Token(2,drops))).or_else_if(OwnedPredicate(Token(1,drops),calls,accept),OwnedEffect(Token(3,drops),calls)).get()
    assert_equal(calls[],11 if accept else 1)
    assert_equal(drops[],2)
    comptime if accept: assert_equal(result._ok().value.value,2)
    else: assert_equal(result._err().value.value,2)
    _ = result^
    assert_equal(drops[],3)


def failures() raises:
    comptime I = ResultT[IdentityFamily,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var code = 0
    try: _ = pipeline[I](I.fail[Token](Token(2,drops))).recover_if(FailedPredicate(Token(1,drops),calls),OwnedRestore(Token(3,drops),calls)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,845)
    assert_equal(calls[],1)
    assert_equal(drops[],3)
    try: _ = pipeline[I](I.fail[Token](Token(2,drops))).recover_if(OwnedPredicate(Token(1,drops),calls,True),OwnedFailure(Token(3,drops),calls)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,711)
    assert_equal(calls[],3)
    assert_equal(drops[],6)


def deferred[execute: Bool, accept: Bool, success: Bool]() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = I.pure(Token(2,drops)) if success else I.fail[Token](Token(2,drops))
    var pending = pipeline[I](source^).recover_if(OwnedPredicate(Token(1,drops),calls,accept),OwnedRestore(Token(3,drops),calls)).get()
    assert_equal(drops[],0)
    assert_equal(calls[],0)
    comptime if execute:
        var result = run[R](pending^,0)
        assert_equal(drops[],2)
        comptime if success or accept: assert_equal(result._ok().value.value,2)
        else: assert_equal(result._err().value.value,2)
    else:
        _ = pending^
    assert_equal(drops[],3)
    assert_equal(calls[],(2 if accept else 1) if execute and not success else 0)


@fieldwise_init
struct Decision[T: Movable & Deinitable](BorrowCallable):
    var accept: Bool
    comptime Payload = Self.T
    comptime Result = Bool
    def invoke(self, value: Self.T) -> Bool: return self.accept


def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime I = ResultT[IdentityFamily,View]
    var kept = pipeline[I](I.fail[View](Span(owner))).recover_if(Decision[View](False),Stored[View]()).get()
    comptime assert type_of(kept) == Result[View,View]
    assert_equal(kept._err().value.unsafe_ptr() == Span(owner).unsafe_ptr(),True)
    var restored = pipeline[I](I.fail[View](Span(owner))).recover_if(Decision[View](True),Stored[View]()).get()
    assert_equal(restored._ok().value.unsafe_ptr() == Span(owner).unsafe_ptr(),True)


def main() raises:
    values[False,False]()
    values[False,True]()
    values[True,False]()
    values[True,True]()
    effects[False]()
    effects[True]()
    failures()
    deferred[True,True,False]()
    deferred[True,False,False]()
    deferred[True,True,True]()
    deferred[False,True,False]()
    origins(List[Int]([7,8]))
