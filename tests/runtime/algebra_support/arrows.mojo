"""Reader and State traversal own one deferred loop, including sequence."""
from fp.algebra import traverse, sequence, ListFamily
from fp.effects import Reader, State, run, action
from fp.callables import Unary, OnceUnary, BorrowCallable, BorrowOnceCallable
from std.memory import ArcPointer

@fieldwise_init
struct ReadStep(BorrowOnceCallable):
    var item:Int
    comptime Payload=Int
    comptime Result=Int
    def invoke_once(deinit self,ref environment:Int) raises Never capturing ->Int:
        return self.item+environment

@fieldwise_init
struct ReadInt(BorrowCallable,Defaultable):
    comptime Payload=Int
    comptime Result=Int
    def invoke(self,ref value:Int) raises Never capturing ->Int:
        return value

@fieldwise_init
struct StateStep(OnceUnary):
    var item:Int
    comptime Arg=Int
    comptime Out=Tuple[Int,Int]
    def call_once(deinit self,var state:Int)->Tuple[Int,Int]:
        var updated=state+self.item
        return Tuple(updated,updated)

@fieldwise_init
struct Produce[stateful:Bool](Unary):
    var calls:ArcPointer[Int]
    comptime Arg=Int
    comptime Out=type_of(action[State[Int],Int](StateStep(0))) if Self.stateful else type_of(action[Reader[Int],Int](ReadStep(0)))
    def call(self,var item:Int)->Self.Out:
        self.calls[]+=1
        comptime if Self.stateful:
            return rebind_var[Self.Out](action[State[Int],Int](StateStep(item)))
        else:
            return rebind_var[Self.Out](action[Reader[Int],Int](ReadStep(item)))

from std.builtin.rebind import rebind_var
