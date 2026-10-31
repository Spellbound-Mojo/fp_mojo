"""Native, callable and generic fluent combinations keep their ordinary syntax."""
from fp.algebra import Applicative, ListFamily, map2_lazy
from fp.algebra.contracts import CombineContract
from fp.functions import pipeline
from fp.callables import Unary,BinaryContract,ThunkContract
from fp.callables._transforms import _ValueThunk
from context_combination_admission_support import Add
from std.testing import assert_equal

@fieldwise_init
struct Plus(Unary,Copyable):
    var delta:Int
    comptime Arg=Int
    comptime Out=Int
    def call(self,var value:Int)->Int:return value+self.delta

def generic_product[A:Copyable & Deinitable,B:Copyable & Deinitable](var left:List[A],var right:List[B])->List[Tuple[A,B]]:
    return pipeline(left^).product(right^).get()

def generic_combine[I:Applicative,V:Movable & Deinitable,F:BinaryContract & Movable & Deinitable,R:ThunkContract & Movable & Deinitable](var left:V,var function:F,var right:R) raises CombineContract[I,V,F,R].Error -> CombineContract[I,V,F,R].Out where CombineContract[I,V,F,R].Compatible:
    return map2_lazy[I](left^,right^,function^)

def add(var first:Int,var second:Int)->Int:return first+second

def main() raises:
    assert_equal(pipeline(List[Int]([1,2])).map2(List[Int]([10,20]),add).get(),[11,21,12,22])
    assert_equal(pipeline(List[Int]([1,2])).map2(List[Int]([10,20]),Add()).get(),[11,21,12,22])
    var pairs=generic_product(List[Int]([1,2]),List[String](["x"]))
    assert_equal(pairs[0][0],1)
    assert_equal(pairs[1][1],"x")
    assert_equal(pipeline(List[Plus]([Plus(1),Plus(2)])).ap(List[Int]([10,20])).get(),[11,21,12,22])
    assert_equal(generic_combine[ListFamily](List[Int]([1,2]),Add(),_ValueThunk(List[Int]([10,20]))),[11,21,12,22])
