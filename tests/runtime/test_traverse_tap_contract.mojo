"""Generic contracts preserve traversal shape, family policies and exact errors."""
from algebra_support.tap_contracts import observed, continued, Keep
from algebra_support.box import Box, BoxApplicative
from algebra_support.external import PublicMonad
from fp.algebra import Traversable, Applicative, ListFamily, OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.algebra.contracts import TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowMutableCallable, BorrowOnceCallable, BorrowSignature
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

# Bidirectional equivalence with the old, expanded selected-entry requirements.
from fp.algebra._sequencing import _EffectRetain

def expanded[S: Traversable, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var values: V, var callback: C) raises TraverseTapContract[S,G,V,C].Error -> TraverseTapContract[S,G,V,C].Out where C.Payload == S.Element[V] and G.CarrierCompatible[C.Result] and S.TraverseCompatible[V,_EffectRetain[S.Element[V],G,C]] and S.TargetCompatible[G,V,_EffectRetain[S.Element[V],G,C]]:
    return selected[S,G](values^,callback^)

def selected[S: Traversable, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var values: V, var callback: C) raises TraverseTapContract[S,G,V,C].Error -> TraverseTapContract[S,G,V,C].Out where TraverseTapContract[S,G,V,C].Compatible:
    return pipeline[S](values^).traverse_tap[G](callback^).get()

def forwarded[S: Traversable, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var values: V, var callback: C) raises TraverseTapContract[S,G,V,C].Error -> TraverseTapContract[S,G,V,C].Out where TraverseTapContract[S,G,V,C].Compatible:
    return expanded[S,G](values^,callback^)

@fieldwise_init
struct Count(BorrowMutableCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Optional[NoneType]
    def invoke_mut(mut self, value: Int) -> Self.Result:
        self.calls[] += 1
        return Optional(NoneType())

@fieldwise_init
struct Once(BorrowOnceCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Optional[NoneType]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        self.calls[] += 1
        return Optional(NoneType())


def main() raises:
    assert_equal(observed[ListFamily,OptionalFamily](List[Int]([1,2]),Keep[Int]()).value(),[1,2])
    assert_equal(forwarded[ListFamily,OptionalFamily](List[Int]([1,2]),Keep[Int]()).value(),[1,2])
    assert_equal(observed[OptionalFamily,OptionalFamily](Optional(3),Keep[Int]()).value().value(),3)
    var calls = ArcPointer(0)
    assert_equal(observed[ListFamily,OptionalFamily](List[Int](),Count(calls)).value(),List[Int]())
    assert_equal(calls[],0)
    assert_equal(observed[ListFamily,OptionalFamily](List[Int]([1,2]),Count(calls)).value(),[1,2])
    assert_equal(calls[],2)
    assert_equal(observed[OptionalFamily,OptionalFamily](Optional(3),Once(calls)).value().value(),3)
    assert_equal(calls[],3)
    _ = observed[OptionalFamily,OptionalFamily](Optional[Int](),Once(calls))
    assert_equal(calls[],3)
    var fluent = continued[OptionalFamily,OptionalFamily](pipeline(Optional(5)).raising[Int](),Keep[Int]())
    comptime assert type_of(fluent).E == Int
    assert_equal(fluent^.get().value().value(),5)
    var source_error = observed[ResultFamily[String],OptionalFamily](Result[Int,String](Err(String("source"))),Count(calls))
    var source_result = source_error.take()
    assert_equal(source_result^.swap().to_optional().value(),"source")
    assert_equal(calls[],3)
    def fail(value: Int) {calls} -> Result[NoneType,String]:
        calls[] += 1
        return Err(String(value))
    var stopped = observed[ListFamily,ResultFamily[String]](List[Int]([1,2,3]),BorrowSignature[Int,Result[NoneType,String]].capture(fail))
    assert_equal(stopped^.swap().to_optional().value(),"1")
    assert_equal(calls[],4)
    def branches(value: Int) -> List[NoneType]: return List[NoneType]([NoneType(),NoneType()])
    var branched = observed[ListFamily,ListFamily](List[Int]([1,2]),BorrowSignature[Int,List[NoneType]].capture(branches))
    assert_equal(len(branched),4)
    for values in branched: assert_equal(values,[1,2])
    def boxed(value: Int) -> Box[NoneType]: return Box(NoneType())
    assert_equal(observed[ListFamily,BoxApplicative](List[Int]([1,2]),BorrowSignature[Int,Box[NoneType]].capture(boxed)).value,[1,2])
    def invalid(value: Int) -> Result[NoneType,List[String]]: return Err(List[String]([String(value)]))
    comptime Validation = ValidationFamily[ListMonoid[String]]
    var accumulated = observed[ListFamily,Validation](List[Int]([1,2]),BorrowSignature[Int,Result[NoneType,List[String]]].capture(invalid))
    assert_equal(accumulated^.swap().to_optional().value(),List[String](["1","2"]))
    var caught = 0
    try: _ = observed[ListFamily,PublicMonad[OptionalFamily,1]](List[Int]([1,2]),Keep[Int]())
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,702)
