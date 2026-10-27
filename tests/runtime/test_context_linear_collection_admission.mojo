from fp.algebra import IdentityFamily,OptionalFamily,ResultFamily,ValidationFamily,ListFamily,TraverseContract,ListMonoid,BindContract,flat_map
from fp.algebra.protocols import _Accumulate,Semigroup
from fp.callables import Unary, NativeUnary
from fp.data import Result,Ok
from context_branch_admission_support import Next,OnceNext,MoveState
from std.testing import assert_equal

struct OwnedAccumulator(_Accumulate):
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

struct StringAccumulator(_Accumulate):
    comptime Acc=Int
    comptime Item=Int
    comptime Error=String
    @staticmethod
    def start() raises String ->Int:return 0
    @staticmethod
    def live(ref value:Int)->Bool:return True
    @staticmethod
    def combine(var value:Int,var item:Int) raises String ->Int:return value+item

struct Errors(Semigroup):
    comptime Value=List[Int]
    comptime Error=Int
    @staticmethod
    def combine(var left:Self.Value,var right:Self.Value) raises Int ->Self.Value:
        left.extend(right^)
        return left^

def accepts[compatible: Bool]() where compatible:
    pass


def generic_validation[A: Movable & Deinitable, R: Movable & Deinitable,
                       E: Movable & Deinitable, F: def(var A) raises E -> R,
                       S: Semigroup]() where S.Error == Never and R == ValidationFamily[S].Pure[ValidationFamily[S].Element[R]]:
    # Existing carrier equality and a non-raising policy prove collection;
    # generic wrappers need no extra structural or accumulator type bounds.
    accepts[ValidationFamily[S].CollectCompatible[List[A], NativeUnary[A, R, E, F, True]]]()


def main() raises:
    comptime R=ResultFamily[String]
    comptime A=ValidationFamily[ListMonoid[String]]
    comptime V=ValidationFamily[Errors]
    comptime assert not IdentityFamily.CollectCompatible[List[Int],OnceNext[IdentityFamily]]
    comptime assert not OptionalFamily.CollectCompatible[List[Int],OnceNext[OptionalFamily]]
    comptime assert not R.CollectCompatible[List[Int],OnceNext[R]]
    comptime assert not A.CollectCompatible[List[Int],OnceNext[A]]
    comptime assert R.BindCompatible[Result[Int,String],OnceNext[R]]
    var bound=flat_map[R](OnceNext[R](),Result[Int,String](Ok(3)))
    assert_equal(bound._ok().value,4)
    comptime assert IdentityFamily._LoopCompatible[List[Int],Next[IdentityFamily],OwnedAccumulator]
    comptime assert OptionalFamily._LoopCompatible[List[Int],Next[OptionalFamily],OwnedAccumulator]
    comptime assert R._LoopCompatible[List[Int],Next[R],OwnedAccumulator]
    comptime assert A._LoopCompatible[List[Int],Next[A],OwnedAccumulator]
    comptime assert not V._LoopCompatible[List[Int],Next[V],StringAccumulator]
    comptime assert not R.CollectCompatible[List[Int],Next[IdentityFamily]]
    comptime assert not OptionalFamily.CollectCompatible[List[Int],Next[IdentityFamily]]
    comptime assert not A.CollectCompatible[List[Int],Next[IdentityFamily]]
    comptime assert not R.CollectCompatible[Int,Next[R]]
    comptime assert not R.CollectCompatible[List[String],Next[R]]
    comptime assert TraverseContract[OptionalFamily,R,Optional[Int],OnceNext[R]].Compatible
    comptime assert not TraverseContract[ListFamily,R,List[Int],OnceNext[R]].Compatible
