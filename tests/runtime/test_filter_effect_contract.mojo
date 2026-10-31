"""Public contracts forward source shape, target policies and construction errors."""
from algebra_support.filter_effect_contracts import filtered, continued, Even, FailingCompaction
from algebra_support.external import PublicMonad
from algebra_support.box import Box, BoxApplicative
from fp.algebra import Traversable, FunctorFilter, Applicative, ListFamily, OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.algebra.contracts import FilterEffectContract
from fp.callables import BorrowCallContract, BorrowSignature, BorrowMutableCallable
from fp.functions import pipeline
from fp.data import Result, Err, Ok
from std.testing import assert_equal

# Old expanded constraints and the public descriptor forward in both directions.
from fp.algebra._traversal import _TraverseTap, _CompactAfter

def selected[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var values: V, var callback: C) raises FilterEffectContract[S,G,V,C].Error -> FilterEffectContract[S,G,V,C].Out where FilterEffectContract[S,G,V,C].Compatible:
    return pipeline[S](values^).filter_effect[G](callback^).get()

def expanded[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var values: V, var callback: C) raises FilterEffectContract[S,G,V,C].Error -> FilterEffectContract[S,G,V,C].Out where C.Payload == S.Element[V] and S.TraverseCompatible[V,_TraverseTap[S.Element[V],G,C,True]] and G.CarrierCompatible[C.Result] and S.TargetCompatible[G,V,_TraverseTap[S.Element[V],G,C,True]] and G.Element[C.Result] == Bool and G.Element[_TraverseTap[S.Element[V],G,C,True].Out] == Optional[S.Element[V]] and G.MapCompatible[S.Traversed[G,V,_TraverseTap[S.Element[V],G,C,True]],_CompactAfter[S,G.Element[S.Traversed[G,V,_TraverseTap[S.Element[V],G,C,True]]]]]:
    return selected[S,G](values^,callback^)

def forwarded[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var values: V, var callback: C) raises FilterEffectContract[S,G,V,C].Error -> FilterEffectContract[S,G,V,C].Out where FilterEffectContract[S,G,V,C].Compatible:
    return expanded[S,G](values^,callback^)

@fieldwise_init
struct Count(BorrowMutableCallable):
    var calls: Int
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke_mut(mut self, value: Int) -> Self.Result:
        self.calls += 1
        return Optional(self.calls % 2 == 0)

def branches(value: Int) -> List[Bool]: return List[Bool]([False,True])
def boxed(value: Int) -> Box[Bool]: return Box(value % 2 == 0)
def fail(value: Int) -> Result[Bool,String]: return Err(String(value))
def invalid(value: Int) -> Result[Bool,List[String]]: return Err(List[String]([String(value)]))

def main() raises:
    assert_equal(filtered[ListFamily,OptionalFamily](List[Int]([1,2,3,4]),Even()).value(),[2,4])
    assert_equal(forwarded[ListFamily,OptionalFamily](List[Int]([1,2,3,4]),Even()).value(),[2,4])
    assert_equal(filtered[ListFamily,OptionalFamily](List[Int](),Even()).value(),List[Int]())
    assert_equal(filtered[OptionalFamily,OptionalFamily](Optional(2),Even()).value().value(),2)
    assert_equal(Bool(filtered[OptionalFamily,OptionalFamily](Optional(3),Even()).value()),False)
    assert_equal(Bool(filtered[OptionalFamily,OptionalFamily](Optional[Int](),Even()).value()),False)
    assert_equal(filtered[ListFamily,OptionalFamily](List[Int]([1,2,3,4]),Count(0)).value(),[2,4])
    var fluent = continued[ListFamily,OptionalFamily](pipeline(List[Int]([1,2,3,4])).raising[Int](),Even())
    comptime assert type_of(fluent).E == Int
    assert_equal(fluent^.get().value(),[2,4])
    var choices = filtered[ListFamily,ListFamily](List[Int]([1,2]),BorrowSignature[Int,List[Bool]].capture(branches))
    assert_equal(len(choices),4)
    assert_equal(choices[0],List[Int]())
    assert_equal(choices[1],[2])
    assert_equal(choices[2],[1])
    assert_equal(choices[3],[1,2])
    assert_equal(filtered[ListFamily,BoxApplicative](List[Int]([1,2]),BorrowSignature[Int,Box[Bool]].capture(boxed)).value,[2])
    var failed = filtered[ListFamily,ResultFamily[String]](List[Int]([1,2]),BorrowSignature[Int,Result[Bool,String]].capture(fail))
    assert_equal(failed^.swap().to_optional().value(),"1")
    comptime Validation = ValidationFamily[ListMonoid[String]]
    var accumulated = filtered[ListFamily,Validation](List[Int]([1,2]),BorrowSignature[Int,Result[Bool,List[String]]].capture(invalid))
    assert_equal(accumulated^.swap().to_optional().value(),List[String](["1","2"]))
    var caught = 0
    try: _ = filtered[ListFamily,PublicMonad[OptionalFamily,1]](List[Int]([1,2]),Even())
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,702)
    caught = 0
    try: _ = filtered[FailingCompaction,OptionalFamily](List[Int]([1,2]),Even())
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,83)
