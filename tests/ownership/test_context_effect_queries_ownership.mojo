"""Searches retain unique owners and clean up captures, inputs and partial folds."""
from fp.functions import pipeline
from fp.algebra import ResultFamily, ListMonoid
from fp.data import Result, Ok, Err
from fp.callables import MutableUnary, MutableBinary
from fp.effects import Reader, run
from std.collections import Array
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct QueryOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct QueryMapper(MutableUnary):
    var capture: QueryOwner
    var calls: ArcPointer[Int]
    comptime Arg = QueryOwner
    comptime Out = Result[Optional[QueryOwner], String]
    def call_mut(mut self, var value: Self.Arg) -> Self.Out:
        self.calls[] += 1
        if value.id < 0: return Err(String("stored"))
        if value.id == self.capture.id: return Ok(Optional(value^))
        return Ok(Optional[QueryOwner]())

@fieldwise_init
struct QueryStep(MutableBinary):
    var calls: Int
    comptime First = List[QueryOwner]
    comptime Second = QueryOwner
    comptime Out = Optional[List[QueryOwner]]
    def call_mut(mut self, var acc: Self.First, var value: Self.Second) -> Self.Out:
        self.calls += 1
        if self.calls == 2: return None
        acc.append(value^)
        return Optional(acc^)

def owners(drops: ArcPointer[Int], fail: Bool = False) -> List[QueryOwner]:
    var result = List[QueryOwner]()
    result.append(QueryOwner(1, drops))
    result.append(QueryOwner(-2 if fail else 2, drops))
    result.append(QueryOwner(3, drops))
    return result^

def choose(value: QueryOwner) -> Optional[Bool]: return Optional(value.id == 2)
def collect(var value: QueryOwner) -> Result[List[QueryOwner], String]:
    if value.id < 0: return Err(String("stored"))
    var result = List[QueryOwner]()
    result.append(value^)
    return Ok(result^)

def main() raises:
    var drops = ArcPointer(0)
    var found = pipeline(owners(drops)).find_effect(choose).get()
    assert_equal(found.value().value().id, 2); assert_equal(drops[], 2)
    _ = found^
    assert_equal(drops[], 3)
    drops[] = 0
    var array: Array[QueryOwner,3] = [QueryOwner(1,drops),QueryOwner(2,drops),QueryOwner(3,drops)]
    var array_found = pipeline(array^).find_effect(choose).get()
    assert_equal(array_found.value().value().id, 2); assert_equal(drops[], 2)
    _ = array_found^
    assert_equal(drops[], 3)
    drops[] = 0
    var calls = ArcPointer(0)
    var mapped = pipeline(owners(drops)).find_map_effect(QueryMapper(QueryOwner(2,drops), calls)).get()
    assert_equal(mapped._ok().value.value().id, 2)
    assert_equal(calls[], 2); assert_equal(drops[], 3)
    _ = mapped^
    assert_equal(drops[], 4)
    drops[] = 0; calls[] = 0
    var failed = pipeline(owners(drops,True)).find_map_effect(QueryMapper(QueryOwner(2,drops),calls)).get()
    assert_equal(failed.is_err(), True); assert_equal(drops[], 4); assert_equal(calls[], 2)
    drops[] = 0
    var combined = pipeline(owners(drops)).fold_map_effect[ResultFamily[String], ListMonoid[QueryOwner]](collect).get()
    assert_equal(combined._ok().value[2].id, 3); assert_equal(drops[], 0)
    _ = combined^
    assert_equal(drops[], 3)
    drops[] = 0
    _ = pipeline(owners(drops,True)).fold_map_effect[ResultFamily[String], ListMonoid[QueryOwner]](collect).get()
    assert_equal(drops[], 3)
    drops[] = 0
    assert_equal(Bool(pipeline(owners(drops)).fold_effect(List[QueryOwner]()).run(QueryStep(0)).get()), False)
    assert_equal(drops[], 3)
    comptime Deferred = Reader[Int]
    def later(value: QueryOwner) -> Deferred.Pure[Bool]: return Deferred.pure(value.id == 2)
    drops[] = 0
    var pending = pipeline(owners(drops)).find_effect[Deferred](later).get()
    assert_equal(drops[], 0)
    var output = run[Deferred](pending^, 0)
    assert_equal(output.value().id, 2); assert_equal(drops[], 2)
    _ = output^
    assert_equal(drops[], 3)
    drops[] = 0
    var abandoned = pipeline(owners(drops)).find_effect[Deferred](later).get()
    _ = abandoned^
    assert_equal(drops[], 3)
    drops[] = 0
    var initial = QueryOwner(0, drops)
    var bound = pipeline(owners(drops)).fold_effect(initial^)
    assert_equal(drops[], 0)
    _ = bound^
    assert_equal(drops[], 4)
