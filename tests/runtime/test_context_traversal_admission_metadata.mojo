"""Loop admission follows the chosen accumulator and exact native error types."""
from fp.algebra import ListFamily,OptionalFamily,ResultFamily,NonEmptyListFamily,TraverseContract
from fp.data import NonEmptyList
from context_branch_admission_support import StatefulMap
from fp.effects import Reader
from fp.algebra.protocols import _Accumulate
from fp.callables import Unary
from context_traversal_admission_support import MoveState,Next

struct MoveAccumulator(_Accumulate):
    comptime Acc=MoveState
    comptime Item=Int
    @staticmethod
    def start()->Self.Acc:return MoveState(0)
    @staticmethod
    def live(ref value:Self.Acc)->Bool:return True
    @staticmethod
    def combine(var acc:Self.Acc,var item:Int)->Self.Acc:
        acc.value+=item
        return acc^

struct MoveItem(_Accumulate):
    comptime Acc=Int
    comptime Item=MoveState
    @staticmethod
    def start()->Int:return 0
    @staticmethod
    def live(ref value:Int)->Bool:return True
    @staticmethod
    def combine(var acc:Int,var item:MoveState)->Int:return acc+item.value

struct StringAccumulator(_Accumulate):
    comptime Acc=Int
    comptime Item=Int
    comptime Error=String
    @staticmethod
    def start() raises String ->Int:return 0
    @staticmethod
    def live(ref value:Int)->Bool:return True
    @staticmethod
    def combine(var acc:Int,var item:Int) raises String ->Int:return acc+item

@fieldwise_init
struct IntProducer(Unary):
    comptime Arg=Int
    comptime Out=List[Int]
    comptime Error=Int
    def call(self,var value:Int) raises Int ->Self.Out:return ListFamily.pure(value)

@fieldwise_init
struct OwnedProducer(Unary):
    comptime Arg=Int
    comptime Out=List[MoveState]
    def call(self,var value:Int)->Self.Out:return ListFamily.pure(MoveState(value))

def main():
    comptime assert not TraverseContract[OptionalFamily,ListFamily,Optional[Int],StatefulMap].Compatible
    comptime assert not TraverseContract[ResultFamily[String],ListFamily,ResultFamily[String].Pure[Int],StatefulMap].Compatible
    comptime assert not TraverseContract[NonEmptyListFamily,ListFamily,NonEmptyList[Int],StatefulMap].Compatible
    comptime I=Reader[Int]
    comptime assert not TraverseContract[OptionalFamily,I,Optional[Int],Next[I]].Compatible
    comptime assert not TraverseContract[ResultFamily[String],I,ResultFamily[String].Pure[Int],Next[I]].Compatible
    comptime assert not ListFamily._LoopCompatible[List[Int],Next[ListFamily],MoveAccumulator]
    comptime assert not ListFamily._LoopCompatible[List[Int],OwnedProducer,MoveItem]
    comptime assert not ListFamily._LoopCompatible[List[Int],IntProducer,StringAccumulator]
    comptime assert ListFamily._LoopCompatible[List[Int],Next[ListFamily],StringAccumulator]
