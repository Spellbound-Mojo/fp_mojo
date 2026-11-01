"""Receiver modes shared by branch admission controls and rejection fixtures."""
from fp.algebra import Applicative, ApplicativeError, Monad
from fp.callables import OnceUnary, Unary, MutableUnary, BorrowOnceCallable, UnaryContract, BinaryContract, ThunkContract
from fp.data import Result,Err

@fieldwise_init
struct OnceMap(OnceUnary):
    comptime Arg=Int
    comptime Out=Int
    def call_once(deinit self,var value:Int)->Int:return value+1

@fieldwise_init
struct StatefulMap(MutableUnary):
    var calls:Int
    comptime Arg=Int
    comptime Out=Int
    def call_mut(mut self,var value:Int)->Int:
        self.calls+=1
        return value+self.calls

@fieldwise_init
struct OnceNext[I:Applicative](OnceUnary):
    comptime Arg=Int
    comptime Out=Self.I.Pure[Int]
    def call_once(deinit self,var value:Int)->Self.Out:return Self.I.pure(value+1)

@fieldwise_init
struct Next[I:Applicative](Unary):
    comptime Arg=Int
    comptime Out=Self.I.Pure[Int]
    def call(self,var value:Int)->Self.Out:return Self.I.pure(value+1)

@fieldwise_init
struct OnceRecovery[I:ApplicativeError](OnceUnary):
    comptime Arg=Self.I.Failure
    comptime Out=Self.I.Pure[Int]
    def call_once(deinit self,var error:Self.Arg)->Self.Out:return Self.I.pure(7)

@fieldwise_init
struct OnceValue(OnceUnary):
    comptime Arg=String
    comptime Out=Int
    def call_once(deinit self,var error:String)->Int:return error.byte_length()

@fieldwise_init
struct Value(Unary):
    comptime Arg=String
    comptime Out=Int
    def call(self,var error:String)->Int:return error.byte_length()

@fieldwise_init
struct OnceObserver(BorrowOnceCallable):
    comptime Payload=String
    comptime Result=Int
    def invoke_once(deinit self,ref error:String)->Int:return error.byte_length()


@fieldwise_init
struct MoveState(Movable):
    var value:Int

@fieldwise_init
struct FailedBranches(OnceUnary):
    comptime Arg=MoveState
    comptime Out=List[Result[Tuple[Int,MoveState],String]]
    def call_once(deinit self,var state:MoveState)->Self.Out:
        return [Result[Tuple[Int,MoveState],String](Err(String("first"))),Result[Tuple[Int,MoveState],String](Err(String("second")))]

@fieldwise_init
struct TakeState(MutableUnary):
    var calls:Int
    comptime Arg=MoveState
    comptime Out=Int
    def call_mut(mut self,var state:MoveState)->Int:
        self.calls+=1
        return state.value+self.calls


struct AdmissionBase[M:Monad,allow_map:Bool=True](Monad):
    """Carrier membership remains independent of one rejected operation."""
    comptime Element[V:Movable & Deinitable]=Self.M.Element[V]
    comptime CarrierCompatible[V:Movable & Deinitable]=Self.M.CarrierCompatible[V]
    comptime MapCompatible[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.allow_map and Self.M.MapCompatible[V,F]
    comptime BindCompatible[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.M.BindCompatible[V,F]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.M.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.M.MapError[V,F]
    comptime Pure[A:Movable & Deinitable]=Self.M.Pure[A]
    comptime Combined[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable]=Self.M.Combined[V,F,R]
    comptime CombineError[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable]=Self.M.CombineError[V,F,R]
    comptime Bound[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.M.Bound[V,F]
    comptime BindError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=Self.M.BindError[V,F]
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.MapError[V,F]->Self.Mapped[V,F]:
        comptime assert Self.MapCompatible[V,F]
        return Self.M.map(f^,value^)
    @staticmethod
    def pure[A:Movable & Deinitable](var value:A)->Self.Pure[A]:return Self.M.pure(value^)
    @staticmethod
    def flat_map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var value:V) raises Self.BindError[V,F]->Self.Bound[V,F]:
        comptime assert Self.BindCompatible[V,F]
        return Self.M.flat_map(f^,value^)
    @staticmethod
    def map2_lazy[V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](var f:F,var left:V,var right:R) raises Self.CombineError[V,F,R]->Self.Combined[V,F,R]:return Self.M.map2_lazy(f^,left^,right^)
