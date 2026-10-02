"""Shared Applicative dictionary and exact native traversal forwarding contract."""
from fp.algebra import Applicative, Traversable, ResultFamily, traverse
from fp.callables import Unary, UnaryContract, BinaryContract, ThunkContract
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer

comptime _R = ResultFamily[Int]

struct ResultApplicative(Applicative):
    # Delegate existing Result semantics; deliberately no Monad, and the
    # inherited collection loop is used unchanged.
    comptime Element[V: Movable & Deinitable] = _R.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _R.Mapped[V, F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _R.MapError[V, F]
    comptime Pure[A: Movable & Deinitable] = _R.Pure[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _R.Combined[V, F, R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _R.CombineError[V, F, R]
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        return _R.map(f^, value^)
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return _R.pure(value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        return _R.map2_lazy(f^, left^, right^)

@fieldwise_init
struct Produce(Unary):
    var calls:ArcPointer[Int]
    var fail:Int
    comptime Arg = Int
    comptime Out = Result[Int,Int]
    comptime Error = Error
    def call(self, var item: Int) raises -> Result[Int,Int]:
        self.calls[]+=1
        if item==3:
            if self.fail==1:
                return Result[Int,Int](Err(37))
            if self.fail==2:
                raise Error("producer failure")
        return Result[Int,Int](Ok(item+1))

def generic_traverse[S:Traversable,G:Applicative,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var function:F,var source:V) raises S.TraverseError[G,V,F] -> S.Traversed[G,V,F]:
    return traverse[S,G](function^,source^)


from fp.algebra import Monad
from std.testing import assert_equal
from .iterators import Counted
from . import ints

def check_traversal[S:Traversable]() raises:
    comptime assert not conforms_to(ResultApplicative,Monad)
    for count in [0,2,5]:
        for failure in range(3):
            var pulls=0
            var calls=ArcPointer(Int(0))
            var caught=False
            var message=String()
            var pending=Optional[Result[List[Int],Int]]()
            try:
                var actual=generic_traverse[S,ResultApplicative](Produce(calls,failure),Counted(Pointer(to=pulls),0,count))
                comptime assert type_of(actual) == Result[List[Int],Int]
                pending=Optional(rebind_var[Result[List[Int],Int]](actual^))
            except error:
                comptime assert type_of(error) == Error
                message=String(rebind[Error](error))
                caught=True
            if caught:
                assert_equal(message,"producer failure")
            else:
                var output=pending.take()
                assert_equal(output.is_err(),failure==1 and count==5)
                var values=Optional[List[Int]]()
                var stored_code=0
                try:
                    values=Optional(output^.raise_on_err())
                except stored:
                    stored_code=stored
                assert_equal(stored_code,37 if failure==1 and count==5 else 0)
                if values:
                    assert_equal(values.value(),List[Int]() if count==0 else ints(2,3) if count==2 else ints(2,3,4,5,6))
            assert_equal(caught,failure==2 and count==5)
            assert_equal(pulls,3 if failure!=0 and count==5 else count+1)
            assert_equal(calls[],3 if failure!=0 and count==5 else count)
