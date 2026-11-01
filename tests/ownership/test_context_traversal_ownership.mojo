"""Effects retain unique owners, release partial output and consume single-use callbacks."""
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from fp.effects import Reader, run
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ContextTraversalOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct ContextTraversalOnce(BorrowOnceCallable):
    var token: ContextTraversalOwner
    comptime Payload = ContextTraversalOwner
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: Self.Payload) capturing -> Self.Result:
        return Optional(value.id == self.token.id)

def owners(drops: ArcPointer[Int]) -> List[ContextTraversalOwner]:
    var result = List[ContextTraversalOwner]()
    for i in range(3): result.append(ContextTraversalOwner(i + 1, drops))
    return result^

def main() raises:
    var inputs = ArcPointer(0)
    var results = ArcPointer(0)
    var captures = ArcPointer(0)
    def inspect(value: ContextTraversalOwner) {results} -> Optional[ContextTraversalOwner]:
        return Optional(ContextTraversalOwner(value.id + 10, results))
    var kept = pipeline(owners(inputs)).traverse_tap(inspect).get()
    assert_equal(inputs[], 0)
    assert_equal(results[], 3)
    assert_equal(kept.value()[2].id, 3)
    _ = kept^
    assert_equal(inputs[], 3)
    inputs[] = 0
    def choose(value: ContextTraversalOwner) -> Optional[Bool]: return Optional(value.id == 2)
    var selected = pipeline(owners(inputs)).filter_effect(choose).get()
    assert_equal(inputs[], 2)
    assert_equal(selected.value()[0].id, 2)
    _ = selected^
    assert_equal(inputs[], 3)

    var once = pipeline(Optional(ContextTraversalOwner(7, inputs))).filter_effect(ContextTraversalOnce(ContextTraversalOwner(7, captures))).get()
    assert_equal(captures[], 1)
    assert_equal(once.value().value().id, 7)
    _ = once^
    assert_equal(inputs[], 4)
    _ = pipeline(Optional[ContextTraversalOwner]()).filter_effect(ContextTraversalOnce(ContextTraversalOwner(0, captures))).get()
    assert_equal(captures[], 2)
    var one_tap = pipeline(Optional(ContextTraversalOwner(9, inputs))).traverse_tap(ContextTraversalOnce(ContextTraversalOwner(0, captures))).get()
    assert_equal(one_tap.value().value().id, 9)
    assert_equal(captures[], 3)
    _ = one_tap^
    assert_equal(inputs[], 5)

    inputs[] = 0
    def stop(value: ContextTraversalOwner) -> Result[Bool, String]:
        if value.id == 2: return Err(String("stored"))
        return Ok(True)
    var failed = pipeline(owners(inputs)).filter_effect(stop).get()
    assert_equal(failed._err().value, "stored")
    assert_equal(inputs[], 3)
    inputs[] = 0
    _ = pipeline(owners(inputs)).traverse_tap(stop).get()
    assert_equal(inputs[], 3)
    def raise_native(value: ContextTraversalOwner) raises Int -> Optional[Bool]:
        if value.id == 2: raise 2
        return Optional(True)
    inputs[] = 0
    var code = 0
    try: _ = pipeline(owners(inputs)).raising[Int]().filter_effect(raise_native).get()
    except error: code = error
    assert_equal(code, 2)
    assert_equal(inputs[], 3)
    inputs[] = 0
    try: _ = pipeline(owners(inputs)).raising[Int]().traverse_tap(raise_native).get()
    except error: code = error
    assert_equal(code, 2)
    assert_equal(inputs[], 3)

    comptime Deferred = Reader[Int]
    def later(value: ContextTraversalOwner) -> Deferred.Pure[Bool]: return Deferred.pure(value.id == 2)
    inputs[] = 0
    var pending = pipeline(owners(inputs)).filter_effect[Deferred](later).get()
    assert_equal(inputs[], 0)
    var output = run[Deferred](pending^, 0)
    assert_equal(inputs[], 2)
    assert_equal(output[0].id, 2)
    _ = output^
    assert_equal(inputs[], 3)
    inputs[] = 0
    var abandoned = pipeline(owners(inputs)).traverse_tap[Deferred](later).get()
    _ = abandoned^
    assert_equal(inputs[], 3)
