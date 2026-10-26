"""Ensure borrows success payloads and releases one-shot captures exactly once."""
from fp.algebra import ResultFamily, EnsureContract, ApplicativeError, Monad
from fp.callables import BorrowOnceCallable, BorrowCallable
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_family_ensure import checked


@fieldwise_init
struct Token(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct Predicate(BorrowOnceCallable):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Payload = Token
    comptime Result = Bool
    def invoke_once(deinit self, ref value: Token) -> Bool:
        self.calls[] += 1
        return value.value > 0


@fieldwise_init
struct Factory(BorrowOnceCallable):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Payload = Token
    comptime Result = String
    def invoke_once(deinit self, ref value: Token) -> String:
        self.calls[] += 1
        return String(value.value)


@fieldwise_init
struct Raised(BorrowOnceCallable):
    var capture: Token
    comptime Payload = Token
    comptime Result = String
    comptime Failure = Int
    def invoke_once(deinit self, ref value: Token) raises Int -> String: raise 749


def owned[accepted: Bool, failed: Bool]() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var drops = ArcPointer(0)
    var tests = ArcPointer(0)
    var errors = ArcPointer(0)
    var source = I.fail[Token](String("old")) if failed else I.pure(Token(1 if accepted else -1,drops))
    var pending = checked[I](source^,Predicate(Token(2,drops),tests),Factory(Token(3,drops),errors)).get()
    assert_equal(drops[],0)
    assert_equal(tests[],0)
    var result = run[R](pending^,0)
    assert_equal(tests[],0 if failed else 1)
    assert_equal(errors[],0 if failed or accepted else 1)
    assert_equal(drops[],2 if failed or accepted else 3)
    comptime if failed: assert_equal(result._err().value,"old")
    elif accepted: assert_equal(result._ok().value.value,1)
    else: assert_equal(result._err().value,"-1")
    _ = result^
    assert_equal(drops[],2 if failed else 3)


def cleanup_error() raises:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    var drops = ArcPointer(0)
    var tests = ArcPointer(0)
    comptime assert EnsureContract[I,I.Pure[Token],Predicate,Raised].Error == Never
    var pending = checked[I](I.pure(Token(-1,drops)),Predicate(Token(2,drops),tests),Raised(Token(3,drops))).get()
    assert_equal(drops[],0)
    var code = 0
    try: _ = run[R](pending^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,749)
    assert_equal(tests[],1)
    assert_equal(drops[],3)


@fieldwise_init
struct Accept[V: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.V
    comptime Result = Bool
    def invoke(self, ref value: Self.V) -> Bool: return True


@fieldwise_init
struct BorrowedError[V: Copyable & Deinitable](BorrowCallable):
    var value: Self.V
    comptime Payload = Self.V
    comptime Result = Self.V
    def invoke(self, ref value: Self.V) -> Self.Result: return self.value.copy()


def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime R = Reader[Int]
    comptime I = ResultT[R,View]
    var pending = checked[I](I.pure(Span(owner)),Accept[View](),BorrowedError(Span(owner))).get()
    var result = run[R](pending^,0)
    assert_equal(result._ok().value.unsafe_ptr() == Span(owner).unsafe_ptr(),True)


def main() raises:
    owned[True,False]()
    owned[False,False]()
    owned[False,True]()
    cleanup_error()
    origins(List[Int]([1,2]))
