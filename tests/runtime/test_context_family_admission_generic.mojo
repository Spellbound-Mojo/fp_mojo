"""Selected traversal forwards only public family admission predicates."""
from algebra_support.applicative_traversal import ResultApplicative
from algebra_support.external import PublicMonad
from fp.functions import pipeline,Identity
from fp.algebra import Functor,Applicative,Traversable,ListFamily,OptionalFamily,ResultFamily,TraverseContract
from fp.callables import Unary,UnaryContract
from fp.data import Result,Ok
from std.collections import Array
from std.testing import assert_equal

struct ExternalSource(Traversable):
    comptime Element[V:Movable & Deinitable]=ListFamily.Element[V]
    comptime MapCompatible[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=ListFamily.MapCompatible[V,F]
    comptime TraverseCompatible[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=ListFamily.TraverseCompatible[V,F]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=ListFamily.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=ListFamily.MapError[V,F]
    comptime Traversed[G:Applicative,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=ListFamily.Traversed[G,V,F]
    comptime TraverseError[G:Applicative,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable]=ListFamily.TraverseError[G,V,F]
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var function:F,var value:V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return ListFamily.map(function^,value^)
    @staticmethod
    def traverse[G:Applicative,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var function:F,var value:V) raises Self.TraverseError[G,V,F] -> Self.Traversed[G,V,F]:
        return ListFamily.traverse[G](function^,value^)

@fieldwise_init
struct Present[T:Movable & Deinitable](Unary):
    comptime Arg=Self.T
    comptime Out=Optional[Self.T]
    def call(self,var value:Self.T)->Self.Out: return Optional(value^)

def traverse_public[S:Traversable,G:Applicative,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var value:V,var function:F) raises TraverseContract[S,G,V,F].Error -> TraverseContract[S,G,V,F].Out where TraverseContract[S,G,V,F].Compatible:
    return pipeline[S](value^).traverse[G](function^).get()

def sequence_public[S:Traversable,G:Applicative,V:Movable & Deinitable](var value:V) raises TraverseContract[S,G,V,Identity[S.Element[V]]].Error -> TraverseContract[S,G,V,Identity[S.Element[V]]].Out where TraverseContract[S,G,V,Identity[S.Element[V]]].Compatible:
    return pipeline[S](value^).sequence[G]().get()

def origins(owner:List[Int]) raises:
    comptime View=type_of(Span(owner))
    var values=List[View]([Span(owner)])
    var result=traverse_public[ListFamily,OptionalFamily](values^,Present[View]())
    assert_equal(result.value()[0].unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    var stored=List[Result[View,View]]()
    stored.append(Ok(Span(owner)))
    var gathered=sequence_public[ListFamily,ResultFamily[View]](stored^)
    assert_equal(gathered._ok().value[0].unsafe_ptr()==Span(owner).unsafe_ptr(),True)

def main() raises:
    comptime assert ExternalSource.MapCompatible[List[Int],Identity[Int]]
    comptime assert not ExternalSource.MapCompatible[Array[Int,2],Identity[Int]]
    var array:Array[Int,2]=[1,2]
    assert_equal(traverse_public[ExternalSource,OptionalFamily](array^,Present[Int]()).value(),List[Int]([1,2]))
    var nested=List[Optional[Int]]([Optional(3),Optional(4)])
    assert_equal(sequence_public[ExternalSource,OptionalFamily](nested^).value(),List[Int]([3,4]))
    origins(List[Int]([7,8]))
    check_custom_defaults()

def default_present(var value:Int)->Result[Int,Int]: return Ok(value)
def check_custom_defaults() raises:
    comptime assert ResultApplicative.CarrierCompatible[Result[Int,Int]]
    comptime assert not ResultApplicative.CarrierCompatible[Result[Int,String]]
    comptime Wrapped=PublicMonad[ResultFamily[Int]]
    comptime assert Wrapped.CarrierCompatible[Result[Int,Int]]
    comptime assert not Wrapped.CarrierCompatible[Result[Int,String]]
    assert_equal(pipeline(List[Int]([1,2])).traverse[ResultApplicative](default_present).get()._ok().value,List[Int]([1,2]))
