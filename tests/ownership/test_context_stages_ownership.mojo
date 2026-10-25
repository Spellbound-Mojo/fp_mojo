"""Whole-value and terminal adapters preserve move-only cleanup and native origins."""
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.algebra import ResultFamily
from fp.callables import OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal
@fieldwise_init
struct ContextStagesToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
@fieldwise_init
struct ContextStagesCleanupFailure(Movable):
    var code: Int
@fieldwise_init
struct ContextStagesConsume(OnceUnary):
    var owned: ContextStagesToken
    comptime Arg = ContextStagesToken
    comptime Out = Int
    def call_once(deinit self, var input: Self.Arg) -> Int:
        return input.value + self.owned.value

def cleanup(drops: ArcPointer[Int]):
    var items = List[ContextStagesToken]()
    for i in range(3): items.append(ContextStagesToken(i + 1, drops))
    def fail(var acc: ContextStagesToken, var item: ContextStagesToken) raises ContextStagesCleanupFailure -> ContextStagesToken:
        if item.value == 2: raise ContextStagesCleanupFailure(2)
        acc.value += item.value
        return acc^
    try:
        _ = pipeline(items^).raising[ContextStagesCleanupFailure]().fold_left(fail, ContextStagesToken(0, drops)).get()
    except _: pass

def captured(drops: ArcPointer[Int]) raises:
    var state = ContextStagesToken(0, drops)
    def step(var acc: Int, var x: Int) {var state^} -> Int:
        state.value += 1
        return acc + state.value * x
    var result = pipeline(List[Int]([1, 1, 1])).fold_left(step, 0).get()
    assert_equal(result, 6)
    assert_equal(step(0, 1), 4)
    assert_equal(drops[], 0)
    _ = step^

def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def select(var x: Int) {view} -> View: return view
    var result = pipeline(1).then(select).get()
    assert_equal(Pointer(to=result[0]) == Pointer(to=owner[0]), True)
    def keep(var acc: View, var x: Int) -> View: return acc
    var folded = pipeline(List[Int]([1, 2])).fold_left(keep, view).get()
    assert_equal(Pointer(to=folded[1]) == Pointer(to=owner[1]), True)
    def wrap(var x: Int) {view} -> Result[View, String]: return Ok(view)
    var traversed = pipeline(List[Int]([1, 2])).traverse[ResultFamily[String]](wrap).get()
    assert_equal(Pointer(to=traversed._ok().value[1][0]) == Pointer(to=owner[0]), True)
    def fail(var x: Int) raises View {view} -> Int: raise view
    var same = False
    try: _ = pipeline(1).raising[View]().then(fail).get()
    except error: same = Pointer(to=error[0]) == Pointer(to=owner[0])
    assert_equal(same, True)

def main() raises:
    var drops = ArcPointer(0)
    assert_equal(pipeline(ContextStagesToken(2, drops)).then(ContextStagesConsume(ContextStagesToken(3, drops))).get(), 5)
    assert_equal(drops[], 2)
    drops[] = 0
    cleanup(drops)
    assert_equal(drops[], 4)
    drops[] = 0
    captured(drops)
    assert_equal(drops[], 1)
    var owner = List[Int]([7, 11])
    origins(owner)
