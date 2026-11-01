from fp.algebra import Functor, ApplicativeError, Monad
from fp.algebra.contracts import EnsureContract, AttemptTapContract
from fp.callables import UnaryContract, BorrowCallContract, Unary, BorrowCallable
from fp.functions import pipeline, RedeemContract, RedeemWithContract
from fp.data import Result, Ok

@fieldwise_init
struct MissingBorrow[P: AnyType, R: Movable & Deinitable](BorrowCallContract, Movable):
    comptime Payload = Self.P
    comptime Result = Self.R

@fieldwise_init
struct MissingUnary[A: Movable & Deinitable, R: Movable & Deinitable](UnaryContract, Movable):
    comptime Arg = Self.A
    comptime Out = Self.R

@fieldwise_init
struct Positive(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref value: Int) -> Bool: return value > 0

@fieldwise_init
struct Label(BorrowCallable):
    comptime Payload = Int
    comptime Result = String
    def invoke(self, ref value: Int) -> String: return String(value)

@fieldwise_init
struct Show[A: Movable & Deinitable](Unary):
    comptime Arg = Self.A
    comptime Out = String
    def call(self, var value: Self.A) -> String: return String("shown")

@fieldwise_init
struct Next[A: Movable & Deinitable](Unary):
    comptime Arg = Self.A
    comptime Out = Result[String,String]
    def call(self, var value: Self.A) -> Self.Out: return Ok(String("next"))

def legacy_ensure[I:ApplicativeError & Monad,V:Movable & Deinitable,P: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](var source:V,var predicate:P,var factory:G) raises EnsureContract[I,V,P,G].Error -> EnsureContract[I,V,P,G].Out where EnsureContract[I,V,P,G].Compatible:
    return pipeline[I](source^).ensure(predicate^,factory^).get()

def checked_ensure[I:ApplicativeError & Monad,V:Movable & Deinitable,P: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](var source:V,var predicate:P,var factory:G) raises EnsureContract[I,V,P,G].Error -> EnsureContract[I,V,P,G].Out where EnsureContract[I,V,P,G].InvocationCompatible:
    return legacy_ensure[I](source^,predicate^,factory^)

def legacy_redeem[I:Functor,V:Movable & Deinitable,H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source:V,var on_ok:H,var on_err:K) raises RedeemContract[I,V,H,K].Error -> RedeemContract[I,V,H,K].Out where RedeemContract[I,V,H,K].Compatible:
    return pipeline[I](source^).redeem(on_ok^,on_err^).get()

def checked_redeem[I:Functor,V:Movable & Deinitable,H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source:V,var on_ok:H,var on_err:K) raises RedeemContract[I,V,H,K].Error -> RedeemContract[I,V,H,K].Out where RedeemContract[I,V,H,K].InvocationCompatible:
    return legacy_redeem[I](source^,on_ok^,on_err^)

def legacy_redeem_with[I:Functor,V:Movable & Deinitable,H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source:V,var on_ok:H,var on_err:K) raises RedeemWithContract[I,V,H,K].Error -> RedeemWithContract[I,V,H,K].Out where RedeemWithContract[I,V,H,K].Compatible:
    return pipeline[I](source^).redeem_with(on_ok^,on_err^).get()

def checked_redeem_with[I:Functor,V:Movable & Deinitable,H: UnaryContract & Movable & Deinitable, K: UnaryContract & Movable & Deinitable](var source:V,var on_ok:H,var on_err:K) raises RedeemWithContract[I,V,H,K].Error -> RedeemWithContract[I,V,H,K].Out where RedeemWithContract[I,V,H,K].InvocationCompatible:
    return legacy_redeem_with[I](source^,on_ok^,on_err^)

def legacy_attempt_tap[I:ApplicativeError & Monad,V:Movable & Deinitable,C: BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises AttemptTapContract[I,V,C].Error -> AttemptTapContract[I,V,C].Out where AttemptTapContract[I,V,C].Compatible:
    return pipeline[I](source^).attempt_tap(observer^).get()

def checked_attempt_tap[I:ApplicativeError & Monad,V:Movable & Deinitable,C: BorrowCallContract & Movable & Deinitable](var source:V,var observer:C) raises AttemptTapContract[I,V,C].Error -> AttemptTapContract[I,V,C].Out where AttemptTapContract[I,V,C].InvocationCompatible:
    return legacy_attempt_tap[I](source^,observer^)
