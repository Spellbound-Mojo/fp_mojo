"""Traversal postprocessing checks construction errors, preserving deferred ones."""
from fp.iteration import iterated
from fp.combinators import filter_effect, traverse_filter, flat_traverse
from fp.functions import piped
from fp.effects import Reader, ReaderAction, run
from fp.callables import BorrowCallable, Unary
from std.testing import assert_equal
from std.builtin.rebind import rebind

@fieldwise_init
struct Decide(BorrowCallable):
    comptime Payload = Int
    comptime Result = Reader[Int].Pure[Bool]
    comptime Failure = Int
    def invoke(self, value: Int) raises Int -> Self.Result: return decide(value)
@fieldwise_init
struct Select(Unary):
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Optional[Int]]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out: return select(value)
@fieldwise_init
struct Expand(Unary):
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[List[Int]]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out: return expand(value)

def decide(value: Int) raises Int -> Reader[Int].Pure[Bool]:
    if value == 2: raise 73
    return Reader[Int].pure(True)
def select(var value: Int) raises Int -> Reader[Int].Pure[Optional[Int]]:
    if value == 2: raise 73
    return Reader[Int].pure(Optional(value))
def expand(var value: Int) raises Int -> Reader[Int].Pure[List[Int]]:
    if value == 2: raise 73
    return Reader[Int].pure(List[Int]([value]))

def check[V: ReaderAction, o: ImmOrigin](var pending: V, ref[o] environment: Int) raises where Reader[Int].RunCompatible[V,o] and V.Error[o] == Int:
    var caught = 0
    try: _ = run[Reader[Int]](pending^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = rebind[Int](error)
    assert_equal(caught,73)

def abandon():
    _ = iterated(range(4)).filter_effect(Decide())
    _ = iterated(range(4)).traverse_filter[Reader[Int]](Select())
    _ = iterated(range(4)).flat_traverse[Reader[Int]](Expand())
    _ = iterated(range(4)).filter_effect[Reader[Int]](decide)
    _ = iterated(range(4)).traverse_filter[Reader[Int]](select)
    _ = iterated(range(4)).flat_traverse[Reader[Int]](expand)

def main() raises:
    abandon()
    var environment = 0
    check(iterated(range(4)).filter_effect(Decide()),environment)
    check(iterated(range(4)).traverse_filter[Reader[Int]](Select()),environment)
    check(iterated(range(4)).flat_traverse[Reader[Int]](Expand()),environment)
    check(filter_effect[Reader[Int]](Decide(),range(4)),environment)
    check(traverse_filter[Reader[Int]](Select(),range(4)),environment)
    check(flat_traverse[Reader[Int]](Expand(),range(4)),environment)
    check(piped(List[Int]([0,1,2,3])).filter_effect[Reader[Int]](Decide()).get(),environment)
    check(piped(List[Int]([0,1,2,3])).traverse_filter[Reader[Int]](Select()).get(),environment)
    check(piped(List[Int]([0,1,2,3])).flat_traverse[Reader[Int]](Expand()).get(),environment)
    # Raw native callbacks keep explicit target selection and native error types.
    check(iterated(range(4)).filter_effect[Reader[Int]](decide),environment)
    check(iterated(range(4)).traverse_filter[Reader[Int]](select),environment)
    check(iterated(range(4)).flat_traverse[Reader[Int]](expand),environment)
    check(filter_effect[Reader[Int]](decide,range(4)),environment)
    check(traverse_filter[Reader[Int]](select,range(4)),environment)
    check(flat_traverse[Reader[Int]](expand,range(4)),environment)
    check(piped(List[Int]([0,1,2,3])).filter_effect[Reader[Int]](decide).get(),environment)
    check(piped(List[Int]([0,1,2,3])).traverse_filter[Reader[Int]](select).get(),environment)
    check(piped(List[Int]([0,1,2,3])).flat_traverse[Reader[Int]](expand).get(),environment)
