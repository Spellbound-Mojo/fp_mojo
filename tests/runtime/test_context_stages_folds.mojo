"""Terminal folds keep order, empty behavior, early termination, and exact errors."""
from fp.functions import pipeline
from fp.data import ControlFlow, Break, Continue
from fp.callables import Binary
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal
@fieldwise_init
struct ContextStagesFoldFault(Movable):
    var code: Int
@fieldwise_init
struct ContextStagesSource(Iterator):
    var pulls: ArcPointer[Int]
    comptime Element = Int
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.pulls[] > 5: raise StopIteration()
        return self.pulls[]
@fieldwise_init
struct ContextStagesSum(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var a: Int, var b: Int) -> Int: return a + b

def sub(var acc: Int, var x: Int) -> Int: return acc - x
def stop(var acc: Int, var x: Int) -> ControlFlow[String, Int]:
    if x == 3: return Break(String(acc))
    return Continue(acc + x)
def fail(var acc: Int, var x: Int) raises ContextStagesFoldFault -> Int:
    if x == 2: raise ContextStagesFoldFault(acc)
    return acc + x
def never_sub(var acc: Int, var x: Int) raises Never -> Int: return acc - x

def never_fold() -> Int:
    return pipeline(List[Int]([2, 3])).raising[ContextStagesFoldFault]().fold_left(never_sub, 20).get()
def main() raises:
    assert_equal(never_fold(), 15)
    assert_equal(pipeline(List[Int]()).fold_left(sub, 10).get(), 10)
    assert_equal(pipeline(List[Int]([1, 2, 3])).fold_left(sub, 10).get(), 4)
    assert_equal(pipeline(List[Int]([1, 2, 3])).fold_left(ContextStagesSum(), 10).get(), 16)
    assert_equal(Bool(pipeline(List[Int]()).reduce_optional(sub).get()), False)
    assert_equal(pipeline(List[Int]([9])).reduce_optional(sub).get().value(), 9)
    assert_equal(pipeline(List[Int]([9, 2, 1])).reduce_optional(sub).get().value(), 6)
    var pulls = ArcPointer(0)
    var outcome = pipeline(ContextStagesSource(pulls)).fold_until(stop, 0).get()
    assert_equal(outcome^.unwrap[Break[String]]().into_payload(), "3")
    assert_equal(pulls[], 3)
    pulls[] = 0
    var code = 0
    try: _ = pipeline(ContextStagesSource(pulls)).raising[ContextStagesFoldFault]().fold_left(fail, 10).get()
    except error: code = error.code
    assert_equal(code, 11)
    assert_equal(pulls[], 2)
