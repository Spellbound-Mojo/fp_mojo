"""One result-family projection per operation, including independent filtering."""
from fp.algebra import Functor, Filterable, FunctorFilter, FilterContract, FilterMapContract, ListFamily, filter
from fp.callables import BorrowCallable, UnaryContract
from fp.functions import Pipeline, pipeline
from test_context_capability_custom import Independent, Tagged, Choose
from test_context_selection_contracts import Positive
from std.testing import assert_equal
from fp.algebra import Monad, Applicative, Traversable, MapContract, BindContract, TraverseContract, CombineContract, OptionalFamily, map2_lazy
from fp.callables import BinaryContract, ThunkContract
from fp.functions import Identity
from test_context_operation_contracts import Present
from test_context_selection_contracts import Plus, Pending
from std.memory import ArcPointer
from test_context_selection_contracts import Token

def selected[I: Filterable, V: Movable & Deinitable, P: BorrowCallable](var value: V, var predicate: P) raises FilterContract[I,V,P].Error -> Pipeline[FilterContract[I,V,P].Family, FilterContract[I,V,P].Out] where FilterContract[I,V,P].Compatible and conforms_to(I.FilteredFamily, Functor):
    return Pipeline[FilterContract[I,V,P].Family, FilterContract[I,V,P].Out](filter[I](value^, predicate^))

def compacted[I: FunctorFilter,V:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var v:V,var f:F) raises FilterMapContract[I,V,F].Error -> Pipeline[FilterMapContract[I,V,F].Family,FilterMapContract[I,V,F].Out] where FilterMapContract[I,V,F].Compatible:
    return pipeline[I](v^).filter_map(f^)

def main() raises:
    all_contracts()
    assert_equal(filter[Independent](List[Int]([1, -1]), Positive()), [1])
    assert_equal(selected[Tagged](List[Int]([1, -1]), Positive()).get(), [1])
    assert_equal(compacted[Tagged](List[Int]([1, 2]), Choose()).get(), [1, 2])


def mapped[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var value: V, var function: F) raises MapContract[I,V,F].Error -> Pipeline[MapContract[I,V,F].Family,MapContract[I,V,F].Out] where MapContract[I,V,F].Compatible:
    return pipeline[I](value^).map(function^)

def bound[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var value: V, var function: F) raises BindContract[I,V,F].Error -> Pipeline[BindContract[I,V,F].Family,BindContract[I,V,F].Out] where BindContract[I,V,F].Compatible:
    return pipeline[I](value^).flat_map(function^)

def traversed[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var value: V, var function: F) raises TraverseContract[S,G,V,F].Error -> Pipeline[TraverseContract[S,G,V,F].Family,TraverseContract[S,G,V,F].Out] where TraverseContract[S,G,V,F].Compatible:
    return pipeline[S](value^).traverse[G](function^)

def combined[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: V, var right: R, var function: F) raises CombineContract[I,V,F,R].Error -> Pipeline[CombineContract[I,V,F,R].Family,CombineContract[I,V,F,R].Out] where CombineContract[I,V,F,R].Compatible:
    return Pipeline[CombineContract[I,V,F,R].Family,CombineContract[I,V,F,R].Out](map2_lazy[I](left^,right^,function^))

def all_contracts() raises:
    assert_equal(mapped[ListFamily](List[Int]([1,2]),Identity[Int]()).get(), [1,2])
    assert_equal(bound[OptionalFamily](Optional(3),Present[Int]()).get().value(), 3)
    assert_equal(traversed[ListFamily,OptionalFamily](List[Int]([1,2]),Present[Int]()).get().value(), [1,2])
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    assert_equal(combined[OptionalFamily](Optional(3),Pending(calls,Token(drops)),Plus()).get().value(), 10)
    assert_equal(calls[], 1)
    assert_equal(drops[], 1)
    comptime assert FilterContract[Independent,List[Int],Positive].Compatible
    comptime assert not conforms_to(Independent.FilteredFamily, Functor)
