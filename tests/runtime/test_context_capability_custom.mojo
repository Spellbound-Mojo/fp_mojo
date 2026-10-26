from fp.functions import pipeline, Pipeline
from fp.algebra import Functor, Filterable, FunctorFilter, FilterMapContract, ListFamily, filter
from fp.callables import BorrowCallable, UnaryContract, Unary
from std.testing import assert_equal

struct Tagged(Functor, Filterable, FunctorFilter):
    comptime Element[V:Movable & Deinitable] = ListFamily.Element[V]
    comptime Mapped[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = ListFamily.Mapped[V,F]
    comptime MapError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = F.Error
    comptime Filtered[V:Movable & Deinitable,P:BorrowCallable] = V
    comptime FilterError[V:Movable & Deinitable,P:BorrowCallable] = P.Failure
    comptime MapFiltered[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = ListFamily.MapFiltered[V,F]
    comptime MapFilterError[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var v:V) raises F.Error -> Self.Mapped[V,F]: return ListFamily.map(f^,v^)
    @staticmethod
    def filter[V:Movable & Deinitable,P:BorrowCallable](var p:P,var v:V) raises P.Failure -> V: return ListFamily.filter(p^,v^)
    @staticmethod
    def filter_map[V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var f:F,var v:V) raises F.Error -> Self.MapFiltered[V,F]: return ListFamily.filter_map(f^,v^)

struct Independent(Filterable):
    comptime Element[V:Movable & Deinitable] = ListFamily.Element[V]
    comptime Filtered[V:Movable & Deinitable,P:BorrowCallable] = V
    comptime FilterError[V:Movable & Deinitable,P:BorrowCallable] = P.Failure
    @staticmethod
    def filter[V:Movable & Deinitable,P:BorrowCallable](var p:P,var v:V) raises P.Failure -> V: return ListFamily.filter(p^,v^)

def compact_generic[I:FunctorFilter,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var v:V,var f:F) raises I.MapFilterError[V,F] -> Pipeline[FilterMapContract[I,V,F].Family,FilterMapContract[I,V,F].Out] where F.Arg==I.Element[V]:
    return pipeline[I](v^).filter_map(f^)

@fieldwise_init
struct Choose(Unary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call(self, var value: Int) -> Self.Out: return Optional(value)

def main() raises:
    def keep(x:Int)->Bool:return x>1
    def choose(var x:Int)->Optional[Int]:return Optional(x)
    def plus(var x:Int)->Int:return x+1
    var filtered=pipeline[Tagged](List[Int]([1,2])).filter(keep)
    comptime assert type_of(filtered).I==Tagged
    assert_equal(filtered^.map(plus).get(),List[Int]([3]))
    var mapped=pipeline[Tagged](List[Int]([1,2])).filter_map(choose)
    comptime assert type_of(mapped).I==Tagged
    assert_equal(mapped^.map(plus).get(),List[Int]([2,3]))
    var forwarded = compact_generic[Tagged](List[Int]([3,4]), Choose())
    comptime assert type_of(forwarded).I == Tagged
    assert_equal(forwarded^.map(plus).get(), List[Int]([4,5]))
    comptime assert not conforms_to(Independent,Functor)
    assert_equal(filter[Independent](keep,List[Int]([1,2])),List[Int]([2]))
