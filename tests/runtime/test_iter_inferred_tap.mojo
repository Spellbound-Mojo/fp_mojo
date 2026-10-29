from algebra_support.iterators import Counted
from algebra_support.box import Box, BoxMonad
from fp.iteration import iterated
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily, OptionalFamily, ValidationFamily, ListMonoid
from fp.callables import BorrowCallable, BorrowMutableCallable, BorrowSignature
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Check(BorrowCallable):
    comptime Payload = Int
    comptime Result = Optional[NoneType]
    def invoke(self, value: Int) -> Self.Result:
        if value < 0: return None
        return Optional(NoneType())

@fieldwise_init
struct Count(BorrowMutableCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Optional[NoneType]
    def invoke_mut(mut self, value: Int) -> Self.Result:
        self.calls[] += 1
        return Optional(NoneType())

@fieldwise_init
struct Keep[T: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.T
    comptime Result = Optional[NoneType]
    def invoke(self, value: Self.T) -> Self.Result: return Optional(NoneType())

def forward[T: Movable & Deinitable](var values: List[T]) -> Optional[List[T]]:
    return iterated(values^).traverse_tap(Keep[T]())


def observe(value: Int) -> Result[NoneType,String]: return Ok(NoneType())
def stop(value: Int) -> Result[NoneType,String]:
    if value == 2: return Err(String("stop"))
    return Ok(NoneType())
def raised(value: Int) raises Int -> Optional[NoneType]:
    if value == 2: raise 91
    return Optional(NoneType())
def never(value: Int) raises Never -> Optional[NoneType]: return Optional(NoneType())
def pure() -> Optional[List[Int]]: return iterated(range(2)).traverse_tap(BorrowSignature[Int,Optional[NoneType],Never].capture(never))
def boxed(value: Int) -> Box[NoneType]: return Box(NoneType())
def invalid(value: Int) -> Result[NoneType,List[String]]: return Err(List[String]([String(value)]))

def main() raises:
    var seen = 0
    def check(value: Int) {mut seen} -> Optional[NoneType]:
        seen += 1
        return Optional(NoneType())
    var values = iterated(List[Int]([1,2,3])).traverse_tap(BorrowSignature[Int,Optional[NoneType],Never].capture(check))
    assert_equal(values.value(),[1,2,3])
    assert_equal(seen,3)
    assert_equal(iterated(List[Int]()).traverse_tap(BorrowSignature[Int,Optional[NoneType],Never].capture(check)).value(),List[Int]())
    assert_equal(seen,3)
    assert_equal(iterated(List[Int]([1,2])).traverse_tap(Check()).value(),[1,2])
    assert_equal(forward(List[Int]([1,2])).value(),[1,2])
    var calls = ArcPointer(0)
    assert_equal(iterated(range(3)).traverse_tap(Count(calls)).value(),[0,1,2])
    assert_equal(calls[],3)
    var named = iterated(List[Int]([1,2])).traverse_tap(BorrowSignature[Int,Result[NoneType,String],Never].capture(observe))
    assert_equal(named^.raise_on_err(),[1,2])
    var pulls = 0
    var stopped = iterated(Counted(Pointer(to=pulls),0,5)).traverse_tap(BorrowSignature[Int,Result[NoneType,String],Never].capture(stop))
    assert_equal(pulls,2)
    assert_equal(stopped^.swap().to_optional().value(),"stop")
    pulls = 0
    var caught = 0
    try: _ = iterated(Counted(Pointer(to=pulls),0,5)).traverse_tap(BorrowSignature[Int,Optional[NoneType],Int].capture(raised))
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,91)
    assert_equal(pulls,2)
    assert_equal(pure().value(),[0,1])
    # Legacy target and native callback slots retain their order.
    _ = iterated(range(2)).traverse_tap[OptionalFamily,Never,type_of(never)](never)
    _ = iterated(range(2)).traverse_tap[G=OptionalFamily,X=Error](Check())
    var external = iterated(range(3)).traverse_tap[BoxMonad](boxed)
    assert_equal(external.value,[0,1,2])
    comptime V = ValidationFamily[ListMonoid[String]]
    var accumulated = iterated(range(2)).traverse_tap[V](invalid)
    assert_equal(accumulated^.swap().to_optional().value(),List[String](["0","1"]))
