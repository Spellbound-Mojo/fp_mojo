"""Selected outcomes retain owners until one deferred branch consumes them."""
from fp.algebra import Applicative, ResultFamily
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline
from fp.callables import OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_recovery_contracts import Token, OwnedFailure, Stored


@fieldwise_init
struct OwnedValue[weight: Int](OnceUnary):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Arg = Token
    comptime Out = Token
    def call_once(deinit self, var value: Token) -> Token:
        self.calls[] += Self.weight
        return value^


@fieldwise_init
struct OwnedEffect[I: Applicative, weight: Int](OnceUnary):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Arg = Token
    comptime Out = Self.I.Pure[Token]
    def call_once(deinit self, var value: Token) -> Self.Out:
        self.calls[] += Self.weight
        return Self.I.pure(value^)


def deferred[execute: Bool, success: Bool, effect: Bool]() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = I.pure(Token(2,drops)) if success else I.fail[Token](Token(2,drops))
    comptime if effect:
        var pending = pipeline[I](source^).redeem_with(OwnedEffect[I,1](Token(1,drops),calls),OwnedEffect[I,10](Token(3,drops),calls)).get()
        assert_equal(drops[],0)
        assert_equal(calls[],0)
        comptime if execute:
            var result = run[R](pending^,0)
            assert_equal(drops[],2)
            assert_equal(result._ok().value.value,2)
        else:
            _ = pending^
    else:
        var pending = pipeline[I](source^).redeem(OwnedValue[1](Token(1,drops),calls),OwnedValue[10](Token(3,drops),calls)).get()
        assert_equal(drops[],0)
        assert_equal(calls[],0)
        comptime if execute:
            var result = run[R](pending^,0)
            assert_equal(drops[],2)
            assert_equal(result._ok().value.value,2)
        else:
            _ = pending^
    assert_equal(drops[],3)
    assert_equal(calls[],(1 if success else 10) if execute else 0)


def failed[success: Bool]() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,Token]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = I.pure(Token(2,drops)) if success else I.fail[Token](Token(2,drops))
    var pending = pipeline[I](source^).redeem(OwnedFailure(Token(1,drops),calls),OwnedFailure(Token(3,drops),calls)).get()
    assert_equal(drops[],0)
    assert_equal(calls[],0)
    var code = 0
    try: _ = run[R](pending^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,711)
    assert_equal(drops[],3)
    assert_equal(calls[],1)


@fieldwise_init
struct RaisedView[T: Movable & Deinitable](OnceUnary):
    comptime Arg = Self.T
    comptime Out = Self.T
    comptime Error = Self.T
    def call_once(deinit self, var value: Self.T) raises Self.T -> Self.T: raise value^


def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime R = Reader[Int]
    comptime I = ResultT[R,View]
    var pending = pipeline[I](I.fail[View](Span(owner))).redeem(Stored[View](),Stored[View]()).get()
    var result = run[R](pending^,0)
    comptime assert type_of(result) == ResultFamily[View].Pure[View]
    assert_equal(result._ok().value.unsafe_ptr() == Span(owner).unsafe_ptr(),True)
    var failed = pipeline[I](I.pure(Span(owner))).redeem(RaisedView[View](),RaisedView[View]()).get()
    var caught = False
    try: _ = run[R](failed^,0)
    except error:
        comptime assert type_of(error) == View
        caught = error.unsafe_ptr() == Span(owner).unsafe_ptr()
    assert_equal(caught,True)


def main() raises:
    deferred[True,True,False]()
    deferred[True,False,False]()
    deferred[False,True,False]()
    deferred[False,False,False]()
    deferred[True,True,True]()
    deferred[True,False,True]()
    deferred[False,True,True]()
    deferred[False,False,True]()
    failed[True]()
    failed[False]()
    origins(List[Int]([7,8]))
