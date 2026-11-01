"""Compaction, flattening and discard move owners and release abandoned effects."""
from fp.functions import pipeline
from fp.callables import OnceUnary
from fp.effects import Reader, run
from fp.data import Result, Ok, Err
from std.collections import Array
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct TraversalOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct OnceSelect(OnceUnary):
    var capture: TraversalOwner
    comptime Arg = TraversalOwner
    comptime Out = Optional[Optional[TraversalOwner]]
    def call_once(deinit self, var value: Self.Arg) -> Self.Out:
        return Optional(Optional(value^))

def owners(drops: ArcPointer[Int]) -> List[TraversalOwner]:
    var values = List[TraversalOwner]()
    for i in range(3): values.append(TraversalOwner(i + 1, drops))
    return values^
def select(var value: TraversalOwner) -> Optional[Optional[TraversalOwner]]:
    if value.id == 2: return Optional(Optional(value^))
    return Optional(Optional[TraversalOwner]())
def expand(var value: TraversalOwner) -> Optional[List[TraversalOwner]]:
    var values = List[TraversalOwner]()
    values.append(value^)
    return Optional(values^)

def main() raises:
    var drops = ArcPointer(0)
    var selected = pipeline(owners(drops)).traverse_filter(select).get()
    assert_equal(selected.value()[0].id, 2); assert_equal(drops[], 2)
    _ = selected^
    assert_equal(drops[], 3)
    drops[] = 0
    var flattened = pipeline(owners(drops)).flat_traverse(expand).get()
    assert_equal(flattened.value()[2].id, 3); assert_equal(drops[], 0)
    _ = flattened^
    assert_equal(drops[], 3)
    drops[] = 0
    var nested = List[Optional[Optional[TraversalOwner]]]()
    nested.append(Optional(Optional(TraversalOwner(1,drops))))
    nested.append(Optional(Optional[TraversalOwner]()))
    nested.append(Optional(Optional(TraversalOwner(3,drops))))
    var sequenced = pipeline(nested^).sequence_filter().get()
    assert_equal(len(sequenced.value()), 2); assert_equal(drops[], 0)
    _ = sequenced^
    assert_equal(drops[], 2)
    drops[] = 0
    var captures = ArcPointer(0)
    var once = pipeline(Optional(TraversalOwner(1,drops))).traverse_filter(OnceSelect(TraversalOwner(9,captures))).get()
    assert_equal(once.value().value().id, 1); assert_equal(captures[], 1)
    _ = once^
    assert_equal(drops[], 1)
    var skipped = pipeline(Result[TraversalOwner,String](Err(String("source")))).traverse_void(OnceSelect(TraversalOwner(9,captures))).get()
    assert_equal(skipped.value()._err().value, "source"); assert_equal(captures[], 2)
    drops[] = 0
    var outputs = ArcPointer(0)
    def produce(var value: TraversalOwner) {outputs} -> Optional[TraversalOwner]:
        return Optional(TraversalOwner(value.id, outputs))
    _ = pipeline(owners(drops)).traverse_void(produce).get()
    assert_equal(drops[], 3); assert_equal(outputs[], 3)
    drops[] = 0; outputs[] = 0
    var array: Array[TraversalOwner,2] = [TraversalOwner(1,drops),TraversalOwner(2,drops)]
    _ = pipeline(array^).traverse_void(produce).get()
    assert_equal(drops[], 2); assert_equal(outputs[], 2)
    comptime Deferred = Reader[Int]
    def later(var value: TraversalOwner) -> Deferred.Pure[Optional[TraversalOwner]]:
        return Deferred.pure(Optional(value^))
    drops[] = 0
    var pending = pipeline(owners(drops)).traverse_filter[Deferred](later).get()
    assert_equal(drops[], 0)
    var result = run[Deferred](pending^, 0)
    assert_equal(result[2].id, 3); assert_equal(drops[], 0)
    _ = result^
    assert_equal(drops[], 3)
    drops[] = 0
    var abandoned = pipeline(owners(drops)).traverse_void[Deferred](later).get()
    _ = abandoned^
    assert_equal(drops[], 3)
