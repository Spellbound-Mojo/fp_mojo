"""Optional invocation proofs reject absent receivers and preserve deferred calls."""
from fp.algebra import ResultFamily, ApplicativeError, EnsureContract, AttemptTapContract
from fp.functions import RedeemContract, RedeemWithContract
from fp.callables import MutableUnary, BorrowOnceCallable
from fp.data import Result, Ok
from fp.effects import Reader, ResultT, run
from std.memory import ArcPointer
from std.testing import assert_equal
from context_outcome_receiver_support import MissingBorrow, MissingUnary, Positive, Label, Show, Next, checked_ensure, checked_redeem, checked_redeem_with, checked_attempt_tap
from test_context_family_attempt_tap_generic import Observe
from test_context_family_ensure_ownership import Token as ValidationToken, Predicate, Factory, Raised, Accept, BorrowedError
from test_context_family_outcome_ownership import OwnedValue, OwnedEffect, RaisedView
from test_context_recovery_contracts import Token, Stored


@fieldwise_init
struct Counter(MutableUnary):
    var counts: List[Int]
    comptime Arg = Int
    comptime Out = String
    def call_mut(mut self, var value: Int) -> String:
        self.counts[0] += value
        return String(self.counts[0])


@fieldwise_init
struct OwnedObserver[I: ApplicativeError](BorrowOnceCallable):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Payload = Result[Int,Self.I.Failure]
    comptime Result = Self.I.Pure[NoneType]
    def invoke_once(deinit self, ref value: Self.Payload) -> Self.Result:
        self.calls[] += 1
        return Self.I.pure(NoneType())


def admission() raises:
    comptime I = ResultFamily[String]
    comptime V = Result[Int,String]
    comptime BadPredicate = EnsureContract[I,V,MissingBorrow[Int,Bool],Label]
    comptime BadFactory = EnsureContract[I,V,Positive,MissingBorrow[Int,String]]
    comptime BadOk = RedeemContract[I,V,MissingUnary[Int,String],Show[String]]
    comptime BadError = RedeemContract[I,V,Show[Int],MissingUnary[String,String]]
    comptime BadNextOk = RedeemWithContract[I,V,MissingUnary[Int,Result[String,String]],Next[String]]
    comptime BadNextError = RedeemWithContract[I,V,Next[Int],MissingUnary[String,Result[String,String]]]
    comptime BadObserver = AttemptTapContract[I,V,MissingBorrow[V,Result[NoneType,String]]]
    comptime assert BadPredicate.Compatible and BadFactory.Compatible
    comptime assert BadOk.Compatible and BadError.Compatible
    comptime assert BadNextOk.Compatible and BadNextError.Compatible and BadObserver.Compatible
    comptime assert not BadPredicate.ReceiverCompatible and not BadFactory.InvocationCompatible
    comptime assert not BadOk.ReceiverCompatible and not BadError.InvocationCompatible
    comptime assert not BadNextOk.ReceiverCompatible and not BadNextError.InvocationCompatible
    comptime assert not BadObserver.InvocationCompatible
    assert_equal(checked_ensure[I](I.pure(3),Positive(),Label())._ok().value,3)
    assert_equal(checked_ensure[I](I.pure(-3),Positive(),Label())._err().value,"-3")
    assert_equal(checked_redeem[I](I.pure(3),Show[Int](),Show[String]())._ok().value,"shown")
    assert_equal(checked_redeem[I](I.pure(3),Counter(List[Int]([5])),Show[String]())._ok().value,"8")
    assert_equal(checked_redeem_with[I](I.fail[Int](String("old")),Next[Int](),Next[String]())._ok().value,"next")
    assert_equal(checked_attempt_tap[I](I.pure(7),Observe[I]())._ok().value,7)
    assert_equal(checked_attempt_tap[I](I.fail[Int](String("old")),Observe[I]())._err().value,"old")


def validation() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var factories = ArcPointer(0)
    var pending = checked_ensure[I](I.pure(ValidationToken(1,drops)),Predicate(ValidationToken(2,drops),calls),Factory(ValidationToken(3,drops),factories))
    assert_equal(drops[],0)
    assert_equal(calls[],0)
    var result = run[R](pending^,0)
    assert_equal(calls[],1)
    assert_equal(factories[],0)
    assert_equal(drops[],2)
    _ = result^
    assert_equal(drops[],3)
    comptime assert EnsureContract[I,I.Pure[ValidationToken],Predicate,Raised].Error == Never
    var failure = checked_ensure[I](I.pure(ValidationToken(-1,drops)),Predicate(ValidationToken(2,drops),calls),Raised(ValidationToken(3,drops)))
    var code = 0
    try: _ = run[R](failure^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,749)
    assert_equal(drops[],6)


def outcomes[effect: Bool, success: Bool]() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = I.pure(Token(7,drops)) if success else I.fail[Token](Token(9,drops))
    comptime if effect:
        var pending = checked_redeem_with[I](source^,OwnedEffect[I,1](Token(2,drops),calls),OwnedEffect[I,10](Token(3,drops),calls))
        assert_equal(drops[],0)
        assert_equal(calls[],0)
        var result = run[R](pending^,0)
        assert_equal(result._ok().value.value,7 if success else 9)
        assert_equal(drops[],2)
        _ = result^
    else:
        var pending = checked_redeem[I](source^,OwnedValue[1](Token(2,drops),calls),OwnedValue[10](Token(3,drops),calls))
        assert_equal(drops[],0)
        assert_equal(calls[],0)
        var result = run[R](pending^,0)
        assert_equal(result._ok().value.value,7 if success else 9)
        assert_equal(drops[],2)
        _ = result^
    assert_equal(drops[],3)
    assert_equal(calls[],1 if success else 10)


def observation() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var pending = checked_attempt_tap[I](I.fail[Int](String("retained")),OwnedObserver[I](Token(2,drops),calls))
    assert_equal(drops[],0)
    assert_equal(calls[],0)
    assert_equal(run[R](pending^,0)._err().value,"retained")
    assert_equal(drops[],1)
    assert_equal(calls[],1)
    var skipped = checked_attempt_tap[I](I.pure(4),OwnedObserver[I](Token(3,drops),calls))
    _ = skipped^
    assert_equal(drops[],2)
    assert_equal(calls[],1)


def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime R = Reader[Int]
    comptime I = ResultT[R,View]
    var validated = run[R](checked_ensure[I](I.pure(Span(owner)),Accept[View](),BorrowedError(Span(owner))),0)
    assert_equal(validated._ok().value.unsafe_ptr() == Span(owner).unsafe_ptr(),True)
    var handled = run[R](checked_redeem[I](I.fail[View](Span(owner)),Stored[View](),Stored[View]()),0)
    assert_equal(handled._ok().value.unsafe_ptr() == Span(owner).unsafe_ptr(),True)
    var raised = checked_redeem[I](I.pure(Span(owner)),RaisedView[View](),RaisedView[View]())
    var caught = False
    try: _ = run[R](raised^,0)
    except error:
        comptime assert type_of(error) == View
        caught = error.unsafe_ptr() == Span(owner).unsafe_ptr()
    assert_equal(caught,True)


def main() raises:
    admission()
    validation()
    outcomes[False,True]()
    outcomes[False,False]()
    outcomes[True,True]()
    outcomes[True,False]()
    observation()
    origins(List[Int]([7,8]))
