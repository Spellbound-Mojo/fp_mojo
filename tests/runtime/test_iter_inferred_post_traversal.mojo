"""Typed iterator postprocessing infers targets and preserves effect semantics."""
from fp.iteration import iterated
from fp.callables import Unary, MutableUnary, as_unary, shared_ref, mut_ref
from fp.algebra import OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err
from algebra_support.box import Box, BoxApplicative
from algebra_support.iterators import Counted
from std.testing import assert_equal
@fieldwise_init
struct Select(Unary):
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    def call(self, var value: Int) -> Self.Out: return Optional(Optional(value) if value % 2 == 0 else Optional[Int]())
@fieldwise_init
struct Expand(Unary):
    comptime Arg = Int
    comptime Out = Optional[List[Int]]
    def call(self, var value: Int) -> Self.Out: return Optional(List[Int]([value,value*10]))
def expand(var value: Int) -> Optional[List[Int]]: return Optional(List[Int]([value,value*10]))
@fieldwise_init
struct Keep[T: Movable & Deinitable](Unary):
    comptime Arg = Self.T
    comptime Out = Optional[Optional[Self.T]]
    def call(self, var value: Self.T) -> Self.Out: return Optional(Optional(value^))

def forwarded[T: Movable & Deinitable](var source: List[T]) -> Optional[List[T]]:
    return iterated(source^).traverse_filter(Keep[T]())

@fieldwise_init
struct Count(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls += 1
        return Optional(Optional(value) if self.calls % 2 == 0 else Optional[Int]())

def selected(var value: Int) raises Never -> Optional[Optional[Int]]: return Optional(Optional(value))
def expanded(var value: Int) raises Never -> Optional[List[Int]]: return Optional(List[Int]([value]))
def fail_select(var value: Int) -> Result[Optional[Int],String]:
    if value == 2: return Err(String("stop"))
    return Ok(Optional(value))
def fail_flat(var value: Int) -> Result[List[Int],String]:
    if value == 2: return Err(String("stop"))
    return Ok(List[Int]([value]))
def choices(var value: Int) -> List[Optional[Int]]: return List[Optional[Int]]([Optional[Int](),Optional(value)])
def validate(var value: Int) -> Result[Optional[Int],List[String]]: return Err(List[String]([String(value)]))
def boxed(var value: Int) -> Box[Optional[Int]]: return Box(Optional(value))

def main() raises:
    assert_equal(iterated(range(4)).traverse_filter(Select()).value(),[0,2])
    assert_equal(iterated(range(1,3)).flat_traverse(Expand()).value(),[1,10,2,20])
    assert_equal(iterated(range(1,3)).flat_traverse(as_unary(expand)).value(),[1,10,2,20])
    var borrowed_expander = Expand()
    assert_equal(iterated(range(1,3)).flat_traverse(shared_ref(borrowed_expander)).value(),[1,10,2,20])
    assert_equal(iterated(range(0)).flat_traverse(shared_ref(borrowed_expander)).value(),List[Int]())
    assert_equal(forwarded(List[Int]([1,2])).value(),[1,2])
    var counter = Count(0)
    assert_equal(iterated(range(0)).traverse_filter(mut_ref(counter)).value(),List[Int]())
    assert_equal(counter.calls,0)
    assert_equal(iterated(range(4)).traverse_filter(mut_ref(counter)).value(),[1,3])
    assert_equal(counter.calls,4)
    assert_equal(iterated(range(2)).traverse_filter(mut_ref(counter)).value(),[1])
    assert_equal(counter.calls,6)
    # Old target and native-error/callback slots keep their positions.
    _ = iterated(range(2)).traverse_filter[OptionalFamily,Never,type_of(selected)](selected)
    _ = iterated(range(2)).flat_traverse[OptionalFamily,Never,type_of(expanded)](expanded)
    _ = iterated(range(2)).traverse_filter[G=OptionalFamily,X=Error](Select())
    _ = iterated(range(2)).flat_traverse[G=OptionalFamily,X=Error](Expand())
    var pulls = 0
    var failed = iterated(Counted(Pointer(to=pulls),0,5)).traverse_filter(as_unary(fail_select))
    assert_equal(pulls,2)
    assert_equal(failed^.swap().to_optional().value(),"stop")
    pulls = 0
    var failed_flat = iterated(Counted(Pointer(to=pulls),0,5)).flat_traverse(as_unary(fail_flat))
    assert_equal(pulls,2)
    assert_equal(failed_flat^.swap().to_optional().value(),"stop")
    var branches = iterated(List[Int]([1,2])).traverse_filter(as_unary(choices))
    assert_equal(len(branches),4)
    assert_equal(branches[0],List[Int]())
    assert_equal(branches[1],[2])
    assert_equal(branches[2],[1])
    assert_equal(branches[3],[1,2])
    comptime Validation = ValidationFamily[ListMonoid[String]]
    var accumulated = iterated(range(2)).traverse_filter[Validation](as_unary(validate))
    assert_equal(accumulated^.swap().to_optional().value(),List[String](["0","1"]))
    assert_equal(iterated(range(2)).traverse_filter[BoxApplicative](as_unary(boxed)).value,[0,1])
