from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.callables import OnceUnary, Unary
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct InferredOwner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct InferredOnce(OnceUnary):
    var capture: InferredOwner
    comptime Arg = InferredOwner
    comptime Out = Optional[InferredOwner]
    def call_once(deinit self, var value: Self.Arg) -> Self.Out: return Optional(value^)

@fieldwise_init
struct InferredReject[V: Movable & Deinitable, E: Copyable & Deinitable](Unary):
    var failure: Self.E
    comptime Arg = Self.V
    comptime Out = Result[Self.V, Self.E]
    def call(self, var value: Self.Arg) -> Self.Out: return Err(self.failure.copy())

def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def keep(var value: View) -> Optional[View]: return Optional(value)
    var values = pipeline(List[View]([view])).traverse(keep).get_or(List[View]())
    comptime assert type_of(values) == List[View]
    assert_equal(Pointer(to=values[0][0]) == Pointer(to=owner[0]), True)
    var failed = pipeline(List[View]([view])).traverse(InferredReject[View, Failure](error)).swap().to_optional()
    comptime assert type_of(failed) == Optional[Failure]
    assert_equal(Pointer(to=failed.value()[0]) == Pointer(to=other[0]), True)

def main() raises:
    var inputs = ArcPointer(0)
    var captures = ArcPointer(0)
    var single = pipeline(Optional(InferredOwner(7, inputs))).traverse(InferredOnce(InferredOwner(0, captures))).get()
    assert_equal(single.value().value().id, 7)
    assert_equal(captures[], 1)
    _ = single^
    assert_equal(inputs[], 1)
    _ = pipeline(Optional[InferredOwner]()).traverse(InferredOnce(InferredOwner(0, captures))).get()
    assert_equal(captures[], 2)
    inputs[] = 0
    var source = List[InferredOwner]()
    for i in range(3): source.append(InferredOwner(i, inputs))
    def stop(var value: InferredOwner) -> Optional[InferredOwner]:
        if value.id == 1: return None
        return Optional(value^)
    var absent = pipeline(source^).traverse(stop).get()
    assert_equal(Bool(absent), False)
    assert_equal(inputs[], 3)
    inputs[] = 0
    var effects = List[Optional[InferredOwner]]()
    for i in range(3): effects.append(Optional(InferredOwner(i, inputs)))
    var sequenced = pipeline(effects^).sequence().get()
    assert_equal(sequenced.value()[2].id, 2)
    assert_equal(inputs[], 0)
    _ = sequenced^
    assert_equal(inputs[], 3)
    var capture = InferredOwner(9, captures)
    def closure(var value: Int) {var capture^} -> Optional[Int]: return Optional(value + capture.id)
    assert_equal(pipeline(List[Int]([1])).traverse(closure).get_or(List[Int]()), [10])
    assert_equal(closure(2).value(), 11)
    assert_equal(captures[], 2)
    _ = closure^
    assert_equal(captures[], 3)
    var owner: List[Int] = [3]
    var other: List[Int] = [7]
    origins(owner, other)
