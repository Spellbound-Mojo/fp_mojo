"""Public postprocessing contracts preserve expanded generic admission."""
from algebra_support.post_traversal_contracts import selected, flattened, continued, Select, Expand
from algebra_support.filter_effect_contracts import FailingCompaction
from algebra_support.external import PublicMonad
from algebra_support.box import Box, BoxApplicative
from fp.algebra import Traversable, FunctorFilter, Monad, Applicative, ListFamily, OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.algebra.contracts import TraverseFilterContract, FlatTraverseContract
from fp.callables import UnaryContract, MutableUnary, as_unary, mut_ref
from fp.functions import pipeline, Identity
from fp.data import Result, Ok, Err
from std.testing import assert_equal

# Both directions preserve existing expanded signature proofs.
from fp.algebra._traversal import _CompactAfter, _FlattenAfter
from fp.algebra.instances import _ListElement

def legacy_select[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: V, var function: F) raises TraverseFilterContract[S,G,V,F].Error -> TraverseFilterContract[S,G,V,F].Out where S.Element[V] == F.Arg and S.TraverseCompatible[V,F] and S.TargetCompatible[G,V,F] and G.CarrierCompatible[F.Out] and G.MapCompatible[S.Traversed[G,V,F],_CompactAfter[S,G.Element[S.Traversed[G,V,F]]]] and G.Element[F.Out] == Optional[_ListElement[G.Element[F.Out]]]:
    return pipeline[S](source^).traverse_filter[G](function^).get()

def select_forward[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: V, var function: F) raises TraverseFilterContract[S,G,V,F].Error -> TraverseFilterContract[S,G,V,F].Out where TraverseFilterContract[S,G,V,F].Compatible:
    return legacy_select[S,G](source^,function^)

def legacy_flat[S: Traversable & Monad, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: V, var function: F) raises FlatTraverseContract[S,G,V,F].Error -> FlatTraverseContract[S,G,V,F].Out where S.Element[V] == F.Arg and S.TraverseCompatible[V,F] and S.TargetCompatible[G,V,F] and G.CarrierCompatible[F.Out] and G.MapCompatible[S.Traversed[G,V,F],_FlattenAfter[S,G.Element[S.Traversed[G,V,F]]]] and S.CarrierCompatible[G.Element[F.Out]] and S.BindCompatible[G.Element[S.Traversed[G,V,F]],Identity[S.Element[G.Element[S.Traversed[G,V,F]]]]]:
    return pipeline[S](source^).flat_traverse[G](function^).get()

def flat_forward[S: Traversable & Monad, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: V, var function: F) raises FlatTraverseContract[S,G,V,F].Error -> FlatTraverseContract[S,G,V,F].Out where FlatTraverseContract[S,G,V,F].Compatible:
    return legacy_flat[S,G](source^,function^)

@fieldwise_init
struct Count(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls += 1
        return Optional(Optional(value) if self.calls % 2 == 0 else Optional[Int]())

def branches(var value: Int) -> List[Optional[Int]]: return List[Optional[Int]]([Optional[Int](),Optional(value)])
def boxed(var value: Int) -> Box[Optional[Int]]: return Box(Optional(value))
def invalid(var value: Int) -> Result[Optional[Int],List[String]]: return Err(List[String]([String(value)]))
def nested_result(var value: Int) -> Optional[Result[Int,String]]: return Optional[Result[Int,String]](Ok(value))

def main() raises:
    assert_equal(selected[ListFamily,OptionalFamily](range(4),Select()).value(),[0,2])
    assert_equal(select_forward[ListFamily,OptionalFamily](range(4),Select()).value(),[0,2])
    assert_equal(flattened[ListFamily,OptionalFamily](range(1,3),Expand()).value(),[1,10,2,20])
    assert_equal(flat_forward[ListFamily,OptionalFamily](range(1,3),Expand()).value(),[1,10,2,20])
    assert_equal(selected[ListFamily,OptionalFamily](range(0),Select()).value(),List[Int]())
    assert_equal(flattened[ListFamily,OptionalFamily](range(0),Expand()).value(),List[Int]())
    assert_equal(selected[OptionalFamily,OptionalFamily](Optional(2),Select()).value().value(),2)
    assert_equal(flattened[OptionalFamily,OptionalFamily](Optional(2),Select()).value().value(),2)
    assert_equal(Bool(selected[OptionalFamily,OptionalFamily](Optional(3),Select()).value()),False)
    var source: Result[Int,String] = Err(String("source"))
    var nested = flattened[ResultFamily[String],OptionalFamily](source^,as_unary(nested_result))
    var failed = nested.take()
    assert_equal(failed^.swap().to_optional().value(),"source")
    var counter = Count(0)
    assert_equal(selected[ListFamily,OptionalFamily](range(4),mut_ref(counter)).value(),[1,3])
    assert_equal(counter.calls,4)
    var fluent = continued[ListFamily,OptionalFamily](pipeline(List[Int]([2])).raising[Int](),Expand())
    comptime assert type_of(fluent).E == Int
    assert_equal(fluent^.get().value(),[2,20])
    var choices = selected[ListFamily,ListFamily](List[Int]([1,2]),as_unary(branches))
    assert_equal(len(choices),4)
    assert_equal(choices[0],List[Int]())
    assert_equal(choices[1],[2])
    assert_equal(choices[2],[1])
    assert_equal(choices[3],[1,2])
    assert_equal(selected[ListFamily,BoxApplicative](range(2),as_unary(boxed)).value,[0,1])
    var accumulated = selected[ListFamily,ValidationFamily[ListMonoid[String]]](range(2),as_unary(invalid))
    assert_equal(accumulated^.swap().to_optional().value(),List[String](["0","1"]))
    var caught = 0
    try: _ = selected[FailingCompaction,OptionalFamily](range(2),Select())
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,83)
    caught = 0
    try: _ = flattened[ListFamily,PublicMonad[OptionalFamily,1]](range(2),Expand())
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,702)
