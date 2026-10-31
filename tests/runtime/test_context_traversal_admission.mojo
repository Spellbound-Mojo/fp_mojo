"""Source strategy preserves consuming single-value traversal and checked loops."""
from fp.algebra import Applicative,Traversable,TraverseContract,ListFamily,OptionalFamily,ResultFamily,IdentityFamily,traverse
from fp.algebra.protocols import _Append,_Accumulate
from fp.effects import OptionalT,ResultT
from fp.functions import pipeline,piped
from fp.callables import UnaryContract,OnceUnary,Unary
from fp.data import Result,Ok
from context_branch_admission_support import MoveState,Next,OnceNext,AdmissionBase
from std.testing import assert_equal

from context_traversal_admission_support import OnceOwned,RepeatedOwned,OnceList

def generic[S:Traversable,G:Applicative,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var value:V,var f:F) raises TraverseContract[S,G,V,F].Error -> TraverseContract[S,G,V,F].Out where TraverseContract[S,G,V,F].Compatible:
    return pipeline[S](value^).traverse[G](f^).get()

# The producer itself depends on the target dictionary. Combined admission
# must remain usable after its associated carrier and error types expand.
def optional_generic[G:Applicative](var value:Optional[Int]) raises TraverseContract[OptionalFamily,G,Optional[Int],OnceNext[G]].Error ->TraverseContract[OptionalFamily,G,Optional[Int],OnceNext[G]].Out where TraverseContract[OptionalFamily,G,Optional[Int],OnceNext[G]].Compatible:
    return traverse[G, OptionalFamily](value^,OnceNext[G]())

def result_generic[G:Applicative](var value:Result[Int,String]) raises TraverseContract[ResultFamily[String],G,Result[Int,String],OnceNext[G]].Error ->TraverseContract[ResultFamily[String],G,Result[Int,String],OnceNext[G]].Out where TraverseContract[ResultFamily[String],G,Result[Int,String],OnceNext[G]].Compatible:
    return pipeline[ResultFamily[String]](value^).traverse[G](OnceNext[G]()).get()

def main() raises:
    var wrapped=optional_generic[ListFamily](Optional(3))
    assert_equal(wrapped[0].value(),4)
    var result_wrapped=result_generic[ListFamily](Result[Int,String](Ok(3)))
    assert_equal(result_wrapped[0]._ok().value,4)
    comptime DenyMap=AdmissionBase[ListFamily,False]
    comptime assert not TraverseContract[OptionalFamily,DenyMap,Optional[Int],OnceOwned].Compatible
    comptime assert TraverseContract[IdentityFamily,DenyMap,Int,OnceOwned].Compatible
    var direct=generic[IdentityFamily,DenyMap](6,OnceOwned())
    assert_equal(direct[0].value,6)
    comptime O=OptionalT[ListFamily]
    comptime R=ResultT[ListFamily,String]
    comptime MoveError=ResultT[ListFamily,MoveState]
    comptime assert not TraverseContract[ListFamily,MoveError,List[Int],Next[MoveError]].Compatible
    comptime assert not conforms_to(Next[ListFamily],Copyable)
    comptime assert TraverseContract[ListFamily,ListFamily,List[Int],Next[ListFamily]].Compatible
    comptime assert not TraverseContract[ListFamily,ListFamily,List[Int],OnceNext[ListFamily]].Compatible
    comptime assert not TraverseContract[ListFamily,ListFamily,List[Int],RepeatedOwned[ListFamily]].Compatible
    comptime assert not TraverseContract[ListFamily,O,List[Int],OnceNext[O]].Compatible
    comptime assert not TraverseContract[ListFamily,R,List[Int],RepeatedOwned[R]].Compatible
    comptime assert TraverseContract[OptionalFamily,ListFamily,Optional[Int],OnceOwned].Compatible
    comptime assert not TraverseContract[OptionalFamily,ListFamily,Optional[Int],OnceOwned].CollectCompatible
    var single=generic[OptionalFamily,ListFamily](Optional(7),OnceOwned())
    assert_equal(single[0].value().value,7)
    var result=generic[ResultFamily[String],ListFamily](Result[Int,String](Ok(8)),OnceOwned())
    assert_equal(result[0]._ok().value.value,8)
    var identity=generic[IdentityFamily,ListFamily](List[Int]([9]),OnceList())
    assert_equal(identity[0].value,9)
    var moveonly=generic[ListFamily,OptionalFamily](List[Int]([1,2]),RepeatedOwned[OptionalFamily]())
    assert_equal(moveonly.value()[1].value,2)
    var nested_single=generic[OptionalFamily,O](Optional(4),OnceNext[O]())
    assert_equal(nested_single[0].value().value(),5)
    var options=generic[ListFamily,O](List[Int]([1,2]),Next[O]())
    assert_equal(options[0].value(),[2,3])
    var results=generic[ListFamily,R](List[Int]([1,2]),Next[R]())
    assert_equal(results[0]._ok().value,[2,3])
    def choose(var value:Int)->List[Int]:return [value,value+10]
    var cartesian=traverse[ListFamily, ListFamily](List[Int]([1,2]),choose)
    assert_equal(cartesian[0],[1,2])
    assert_equal(cartesian[3],[11,12])
    assert_equal(piped(List[Int]([1,2])).traverse[ListFamily](choose).get(),cartesian)
    var discarded=pipeline(List[Int]([1,2])).traverse_void[ListFamily](choose).get()
    assert_equal(len(discarded),4)
