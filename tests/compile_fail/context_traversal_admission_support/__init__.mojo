"""Shared receiver and payload controls for source-aware traversal admission."""
from fp.algebra import Applicative, ListFamily
from fp.callables import Unary,OnceUnary
from context_branch_admission_support import MoveState,Next,OnceNext,AdmissionBase
@fieldwise_init
struct OnceOwned(OnceUnary):
    comptime Arg=Int
    comptime Out=List[MoveState]
    def call_once(deinit self,var value:Int)->Self.Out:
        return ListFamily.pure(MoveState(value))

@fieldwise_init
struct RepeatedOwned[I:Applicative](Unary):
    comptime Arg=Int
    comptime Out=Self.I.Pure[MoveState]
    def call(self,var value:Int)->Self.Out:return Self.I.pure(MoveState(value))

@fieldwise_init
struct OnceList(OnceUnary):
    comptime Arg=List[Int]
    comptime Out=List[MoveState]
    def call_once(deinit self,var value:Self.Arg)->Self.Out:return ListFamily.pure(MoveState(value[0]))
