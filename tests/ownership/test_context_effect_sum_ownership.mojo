"""Moves input owners once and releases callbacks and deferred sources exactly once."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.callables import MutableUnary
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct SumOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct SumCallback(MutableUnary):
    var capture: SumOwner
    var calls: ArcPointer[Int]
    comptime Arg = SumOwner
    comptime Out = Result[Int, String]
    def call_mut(mut self, var item: Self.Arg) -> Self.Out:
        self.calls[] += 1
        if item.value < 0: return Err(String("stopped"))
        return Ok(item.value)

def owners(drops: ArcPointer[Int], fail: Bool = False) -> List[SumOwner]:
    var source = List[SumOwner]()
    source.append(SumOwner(1, drops))
    source.append(SumOwner(-2 if fail else 2, drops))
    source.append(SumOwner(3, drops))
    return source^

def main() raises:
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    assert_equal(pipeline(owners(drops)).sum_by_effect(SumCallback(SumOwner(0, drops), calls)).get_or(0), 6)
    assert_equal(drops[], 4); assert_equal(calls[], 3)
    drops[] = 0; calls[] = 0
    assert_equal(pipeline(owners(drops, True)).sum_by_effect(SumCallback(SumOwner(0, drops), calls)).swap().get_or(""), "stopped")
    assert_equal(drops[], 4); assert_equal(calls[], 2)
    drops[] = 0; calls[] = 0
    assert_equal(pipeline(List[SumOwner]()).sum_by_effect(SumCallback(SumOwner(0, drops), calls)).get_or(-1), 0)
    assert_equal(drops[], 1); assert_equal(calls[], 0)
    drops[] = 0
    def fail(var item: SumOwner) raises Int -> Optional[Int]: raise item.value
    var code = 0
    try: _ = pipeline(owners(drops)).raising[Int]().sum_by_effect(fail).get()
    except error: code = error
    assert_equal(code, 1); assert_equal(drops[], 3)
    comptime Deferred = Reader[Int]
    def later(var item: SumOwner) -> Deferred.Pure[Int]: return Deferred.pure(item.value)
    drops[] = 0
    var pending = pipeline(owners(drops)).sum_by_effect[Deferred](later).get()
    assert_equal(drops[], 0)
    assert_equal(run[Deferred](pending^, 0), 6)
    assert_equal(drops[], 3)
    drops[] = 0
    var abandoned = pipeline(owners(drops)).sum_by_effect[Deferred](later).get()
    assert_equal(drops[], 0)
    _ = abandoned^
    assert_equal(drops[], 3)
