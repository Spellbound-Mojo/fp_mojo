"""A declared recovery policy and valid callbacks shared by acceptance/rejection."""
from fp.algebra import ApplicativeError, ResultFamily
from fp.callables import UnaryContract, BorrowCallContract, Unary, BorrowCallable, BinaryContract, ThunkContract
from fp.data import Result, Ok
from std.builtin.rebind import downcast, rebind_var

trait Unavailable:
    comptime Output: Movable & Deinitable

struct Policy[allow: Bool=True, fail_raises: Bool=False, finish: Int=0](ApplicativeError):
    comptime Base=ResultFamily[String]
    comptime Failure=String
    comptime Element[V:Movable & Deinitable]=Self.Base.Element[V]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.Base.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.Base.MapError[V,F]
    comptime MapCompatible[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.finish != 1 and Self.Base.MapCompatible[V,F]
    comptime CombineCompatible[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable]=Self.finish != 2 and Self.Base.CombineCompatible[V,F,R]
    comptime Pure[A:Movable & Deinitable]=Self.Base.Pure[A]
    comptime Combined[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable]=Self.Base.Combined[V,F,R]
    comptime CombineError[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable]=Self.Base.CombineError[V,F,R]
    comptime Failed[A:Movable & Deinitable]=Self.Base.Failed[A]
    comptime FailError[A:Movable & Deinitable]=Int if Self.fail_raises else Never
    comptime Handled[V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable]=Self.Base.Handled[V,H] if Self.allow else downcast[H,Unavailable].Output
    comptime HandleError[V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable]=H.Error
    comptime _ErrorCarrier[V:Movable & Deinitable]=Self.Base.CarrierCompatible[V]
    comptime _Handles[V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable]=Self.allow and Self.Base._Handles[V,H]
    @staticmethod
    def pure[A:Movable & Deinitable](var value:A)->Self.Pure[A]:return Self.Base.pure(value^)
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var source:V) raises Self.MapError[V,F]->Self.Mapped[V,F]:return Self.Base.map(f^,source^)
    @staticmethod
    def map2_lazy[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](var f:F,var left:V,var right:R) raises Self.CombineError[V,F,R]->Self.Combined[V,F,R]:return Self.Base.map2_lazy(f^,left^,right^)
    @staticmethod
    def fail[A:Movable & Deinitable](var error:String) raises Self.FailError[A]->Self.Failed[A]:
        comptime if Self.fail_raises:raise rebind_var[Self.FailError[A]](Int(771))
        else:return Self.Base.fail[A](error^)
    @staticmethod
    def or_else[V:Movable & Deinitable,H:UnaryContract & Movable & Deinitable](var handler:H,var source:V) raises Self.HandleError[V,H]->Self.Handled[V,H]:
        comptime assert Self._Handles[V,H]
        return rebind_var[Self.Handled[V,H]](Self.Base.or_else(handler^,source^))

@fieldwise_init
struct MissingUnary(UnaryContract, Movable):
    comptime Arg=String
    comptime Out=Int
@fieldwise_init
struct MissingBorrow(BorrowCallContract, Movable):
    comptime Payload=String
    comptime Result=Int
@fieldwise_init
struct MissingEffect(UnaryContract, Movable):
    comptime Arg=String
    comptime Out=Result[Int,String]
@fieldwise_init
struct RaiseBorrow(BorrowCallable):
    comptime Payload=String
    comptime Result=Int
    comptime Failure=String
    def invoke(self,ref value:String) raises String->Int:raise String("native")
@fieldwise_init
struct RaisePredicate(BorrowCallable):
    comptime Payload=String
    comptime Result=Bool
    comptime Failure=String
    def invoke(self,ref value:String) raises String->Bool:raise String("native")
