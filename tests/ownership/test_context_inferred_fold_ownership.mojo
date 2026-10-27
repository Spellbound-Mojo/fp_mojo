from fp.functions import pipeline
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct FoldStageOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def abandon(inputs: ArcPointer[Int], seeds: ArcPointer[Int]):
    var source = List[FoldStageOwner]()
    source.append(FoldStageOwner(1, inputs))
    source.append(FoldStageOwner(2, inputs))
    var stage = pipeline(source^).fold_effect(FoldStageOwner(10, seeds))
    _ = stage^

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    def keep(var view: View, var item: Int) -> Optional[View]: return Optional(view)
    var result = pipeline(List[Int]([1, 2])).fold_effect(Span(owner)).run(keep).get()
    comptime assert type_of(result) == Optional[View]
    assert_equal(Pointer(to=result.value()[0]) == Pointer(to=owner[0]), True)
    comptime Deferred = Reader[Int]
    def later(var view: View, var item: Int) -> Deferred.Pure[View]: return Deferred.pure(view)
    var pending = pipeline(List[Int]([1])).fold_effect(Span(owner)).run[Deferred](later).get()
    var retained = run[Deferred](pending^, 0)
    comptime assert type_of(retained) == View
    assert_equal(Pointer(to=retained[0]) == Pointer(to=owner[0]), True)

def main() raises:
    var inputs = ArcPointer(0)
    var seeds = ArcPointer(0)
    abandon(inputs, seeds)
    assert_equal(inputs[], 2)
    assert_equal(seeds[], 1)
    var calls = 0
    def add(var total: FoldStageOwner, var item: FoldStageOwner) {mut calls} -> Optional[FoldStageOwner]:
        calls += 1
        total.value += item.value
        return Optional(total^)
    var source = List[FoldStageOwner]()
    source.append(FoldStageOwner(3, inputs))
    source.append(FoldStageOwner(4, inputs))
    var stage = pipeline(source^).fold_effect(FoldStageOwner(10, seeds))
    assert_equal(calls, 0)
    assert_equal(inputs[], 2)
    var result = stage^.run(add).get()
    assert_equal(result.value().value, 17)
    assert_equal(calls, 2)
    assert_equal(inputs[], 4)
    assert_equal(seeds[], 1)
    _ = result^
    assert_equal(seeds[], 2)
    _ = pipeline(List[FoldStageOwner]()).fold_effect(FoldStageOwner(20, seeds)).run(add).get()
    assert_equal(calls, 2)
    assert_equal(seeds[], 3)

    comptime Deferred = Reader[Int]
    calls = 0
    def later(var total: Int, var item: Int) {mut calls} -> Deferred.Pure[Int]:
        calls += 1
        return Deferred.pure(total + item)
    var pending = pipeline(List[Int]([1, 2])).fold_effect(10).run[Deferred](later).get()
    assert_equal(calls, 0)
    assert_equal(run[Deferred](pending^, 0), 13)
    assert_equal(calls, 2)
    var original = pipeline(List[Int]([1, 2])).fold_effect[Deferred](10).run(later).get()
    assert_equal(calls, 2)
    assert_equal(run[Deferred](original^, 0), 13)
    assert_equal(calls, 4)
    def failed(var total: Int, var item: Int) raises Int {mut calls} -> Deferred.Pure[Int]:
        calls += 1
        raise item
    var delayed = pipeline(List[Int]([5])).raising[Int]().fold_effect(0).run[Deferred](failed).get()
    assert_equal(calls, 4)
    var code = 0
    try: _ = run[Deferred](delayed^, 0)
    except error: code = error
    assert_equal(code, 5)
    assert_equal(calls, 5)
    var owner: List[Int] = [3]
    origins(owner)
