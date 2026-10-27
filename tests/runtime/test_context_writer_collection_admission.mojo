from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily, ListFamily, StringMonoid, Monoid, TraverseContract, traverse
from fp.algebra.protocols import _Accumulate
from fp.effects import Writer, WriterT, OptionalT, ResultT, run_writer
from context_branch_admission_support import Next, OnceNext, MoveState
from std.testing import assert_equal

struct OwnedAcc(_Accumulate):
    comptime Acc=MoveState
    comptime Item=Int
    @staticmethod
    def start()->Self.Acc:return MoveState(0)
    @staticmethod
    def live(ref value:Self.Acc)->Bool:return True
    @staticmethod
    def combine(var value:Self.Acc,var item:Int)->Self.Acc:
        value.value+=item
        return value^

struct StringAcc(_Accumulate):
    comptime Acc=Int
    comptime Item=Int
    comptime Error=String
    @staticmethod
    def start() raises String ->Int:return 0
    @staticmethod
    def live(ref value:Int)->Bool:return True
    @staticmethod
    def combine(var value:Int,var item:Int) raises String ->Int:return value+item

struct FallibleLog(Monoid):
    comptime Value=Int
    comptime Error=Int
    @staticmethod
    def empty() raises Int ->Int:return 0
    @staticmethod
    def combine(var left:Int,var right:Int) raises Int ->Int:return left+right

def main() raises:
    comptime W=Writer[StringMonoid]
    comptime O=WriterT[OptionalFamily,StringMonoid]
    comptime R=WriterT[ResultFamily[String],StringMonoid]
    comptime L=WriterT[ListFamily,StringMonoid]
    comptime assert W.CollectCompatible[List[Int],Next[W]]
    comptime assert not W.CollectCompatible[List[Int],OnceNext[W]]
    comptime assert TraverseContract[OptionalFamily,W,Optional[Int],OnceNext[W]].Compatible
    comptime assert not O.CollectCompatible[List[Int],OnceNext[O]]
    comptime assert not R.CollectCompatible[List[Int],OnceNext[R]]
    comptime assert not L.CollectCompatible[List[Int],OnceNext[L]]
    comptime assert W._LoopCompatible[List[Int],Next[W],OwnedAcc]
    comptime assert O._LoopCompatible[List[Int],Next[O],OwnedAcc]
    comptime assert R._LoopCompatible[List[Int],Next[R],OwnedAcc]
    comptime assert not L._LoopCompatible[List[Int],Next[L],OwnedAcc]
    comptime assert not W.CollectCompatible[Int,Next[W]]
    comptime assert not W.CollectCompatible[List[String],Next[W]]
    comptime assert not W.CollectCompatible[List[Int],Next[IdentityFamily]]
    comptime Fallible=Writer[FallibleLog]
    comptime assert not Fallible._LoopCompatible[List[Int],Next[Fallible],StringAcc]
    assert_equal(run_writer[W](traverse[ListFamily,W](Next[W](),List[Int]([1,2])))[1],[2,3])
    assert_equal(run_writer[W](traverse[OptionalFamily,W](OnceNext[W](),Optional(2)))[1].value(),3)
