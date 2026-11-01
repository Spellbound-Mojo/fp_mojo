"""Combiner and factory modes shared by positive and rejection clients."""
from fp.callables import Unary,Binary,MutableBinary,OnceBinary,ThunkContract,OnceThunk
from std.memory import ArcPointer
from context_branch_admission_support import MoveState,AdmissionBase

@fieldwise_init
struct Add(Binary,Copyable):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    def call(self,var first:Int,var second:Int)->Int:return first+second

@fieldwise_init
struct Stateful(MutableBinary,Copyable):
    var calls:Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    def call_mut(mut self,var first:Int,var second:Int)->Int:
        self.calls+=1
        return first+second+self.calls

@fieldwise_init
struct OnceAdd(OnceBinary,Copyable):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    def call_once(deinit self,var first:Int,var second:Int)->Int:return first+second

@fieldwise_init
struct CapturedAdd(Binary):
    var capture:MoveState
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    def call(self,var first:Int,var second:Int)->Int:return first+second+self.capture.value

@fieldwise_init
struct MoveLeft(Binary,Copyable):
    comptime First=MoveState
    comptime Second=Int
    comptime Out=Int
    def call(self,var first:MoveState,var second:Int)->Int:return first.value+second

@fieldwise_init
struct MoveRight(Binary,Copyable):
    comptime First=Int
    comptime Second=MoveState
    comptime Out=Int
    def call(self,var first:Int,var second:MoveState)->Int:return first+second.value

@fieldwise_init
struct Right[T:Movable & Deinitable](OnceThunk):
    var value:Self.T
    var calls:ArcPointer[Int]
    comptime Out=Self.T
    def call_once(deinit self)->Self.Out:
        self.calls[]+=1
        return self.value^

@fieldwise_init
struct Missing(ThunkContract):
    comptime Out=List[Int]

@fieldwise_init
struct ErrorAdd(Binary,Copyable):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Error=Int
    def call(self,var first:Int,var second:Int) raises Int ->Int:raise 1

@fieldwise_init
struct OtherError(OnceThunk):
    comptime Out=List[Int]
    comptime Error=String
    def call_once(deinit self) raises String ->Self.Out:raise String("different")

@fieldwise_init
struct CapturedUnary(Unary):
    var capture:MoveState
    comptime Arg=Int
    comptime Out=Int
    def call(self,var arg:Int)->Int:return arg+self.capture.value
