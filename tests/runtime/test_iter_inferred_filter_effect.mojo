"""Effectful iterator predicates infer targets from complete callable results."""
from algebra_support.iterators import Counted
from algebra_support.box import Box, BoxApplicative
from fp.iteration import iterated
from fp.data import Result, Ok, Err
from fp.algebra import OptionalFamily, ValidationFamily, ListMonoid
from fp.callables import BorrowCallable, BorrowMutableCallable, BorrowSignature, mut_ref
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Even(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke(self, value: Int) -> Self.Result: return Optional(value % 2 == 0)

@fieldwise_init
struct Count(BorrowMutableCallable):
    var calls: Int
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke_mut(mut self, value: Int) -> Self.Result:
        self.calls += 1
        return Optional(value % 2 == 0)

@fieldwise_init
struct Keep[T: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.T
    comptime Result = Optional[Bool]
    def invoke(self, value: Self.T) -> Self.Result: return Optional(True)

def forward[T: Movable & Deinitable](var values: List[T]) -> Optional[List[T]]:
    return iterated(values^).filter_effect(Keep[T]())

def stop(value: Int) -> Result[Bool,String]:
    if value == 2: return Err(String("stop"))
    return Ok(value % 2 == 0)
def raised(value: Int) raises Int -> Optional[Bool]:
    if value == 2: raise 91
    return Optional(value % 2 == 0)
def never(value: Int) raises Never -> Optional[Bool]: return Optional(True)
def boxed(value: Int) -> Box[Bool]: return Box(value % 2 == 0)
def branches(value: Int) -> List[Bool]: return List[Bool]([False,True])
def invalid(value: Int) -> Result[Bool,List[String]]:
    if value % 2: return Err(List[String]([String(value)]))
    return Ok(False)

def main() raises:
    assert_equal(iterated(range(4)).filter_effect(Even()).value(),[0,2])
    assert_equal(forward(List[Int]([1,2])).value(),[1,2])
    var predicate = Count(0)
    assert_equal(iterated(range(0)).filter_effect(mut_ref(predicate)).value(),List[Int]())
    assert_equal(predicate.calls,0)
    assert_equal(iterated(range(4)).filter_effect(mut_ref(predicate)).value(),[0,2])
    assert_equal(predicate.calls,4)
    assert_equal(iterated(range(2)).filter_effect(mut_ref(predicate)).value(),[0])
    assert_equal(predicate.calls,6)
    var pulls = 0
    var stopped = iterated(Counted(Pointer(to=pulls),0,5)).filter_effect(BorrowSignature[Int,Result[Bool,String]].capture(stop))
    assert_equal(pulls,2)
    assert_equal(stopped^.swap().to_optional().value(),"stop")
    pulls = 0
    var caught = 0
    try: _ = iterated(Counted(Pointer(to=pulls),0,5)).filter_effect(BorrowSignature[Int,Optional[Bool],Int].capture(raised))
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,91)
    assert_equal(pulls,2)
    assert_equal(iterated(range(2)).filter_effect(BorrowSignature[Int,Optional[Bool],Never].capture(never)).value(),[0,1])
    # Existing target, native-error and native-callback parameter slots remain.
    _ = iterated(range(2)).filter_effect[OptionalFamily,Never,type_of(never)](never)
    _ = iterated(range(2)).filter_effect[G=OptionalFamily,X=Error](Even())
    assert_equal(iterated(range(4)).filter_effect[BoxApplicative](boxed).value,[0,2])
    var choices = iterated(List[Int]([1,2])).filter_effect(BorrowSignature[Int,List[Bool]].capture(branches))
    assert_equal(len(choices),4)
    assert_equal(choices[0],List[Int]())
    assert_equal(choices[1],[2])
    assert_equal(choices[2],[1])
    assert_equal(choices[3],[1,2])
    comptime V = ValidationFamily[ListMonoid[String]]
    var accumulated = iterated(range(4)).filter_effect[V](BorrowSignature[Int,Result[Bool,List[String]]].capture(invalid))
    assert_equal(accumulated^.swap().to_optional().value(),List[String](["1","3"]))
