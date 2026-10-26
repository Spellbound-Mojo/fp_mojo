"""Reduction preserves move-only ownership, tie order and mutable callable state."""
from fp.functions import pipeline
from fp.callables import MutableUnary
from std.memory import ArcPointer
from std.collections import Array
from std.testing import assert_equal

@fieldwise_init
struct ReductionOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def owners(drops: ArcPointer[Int]) -> List[ReductionOwner]:
    var values = List[ReductionOwner]()
    for i in range(3): values.append(ReductionOwner(i+1,drops))
    return values^
def select(var value: ReductionOwner) -> Optional[ReductionOwner]:
    if value.id == 2: return Optional(value^)
    return None

@fieldwise_init
struct SumStep(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + self.calls

def main() raises:
    var drops = ArcPointer(0)
    var selected = pipeline(owners(drops)).find_map(select).get()
    assert_equal(selected.value().id,2); assert_equal(drops[],2)
    _ = selected^
    assert_equal(drops[],3)
    drops[]=0
    var calls=ArcPointer(0)
    def key(value: ReductionOwner) {calls} -> Int:
        calls[] += 1
        return 1
    var first = pipeline(owners(drops)).max_by(key).get()
    assert_equal(first.value().id,1); assert_equal(calls[],3); assert_equal(drops[],2)
    _ = first^
    assert_equal(drops[],3)
    drops[]=0
    def number(var value: ReductionOwner) -> Int: return value.id
    var array: Array[ReductionOwner,2] = [ReductionOwner(2,drops),ReductionOwner(3,drops)]
    assert_equal(pipeline(array^).sum_by(number).get(),5); assert_equal(drops[],2)
    drops[]=0
    def fail(var value: ReductionOwner) raises Int -> Int: raise value.id
    var code=0
    try: _ = pipeline(owners(drops)).raising[Int]().sum_by(fail).get()
    except error: code=error
    assert_equal(code,1); assert_equal(drops[],3)
    assert_equal(pipeline(List[Int]([1,2])).sum_by(SumStep(0)).get(),6)
