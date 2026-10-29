"""Typed iterator postprocessing infers targets and preserves effect semantics."""
from fp.iteration import iterated
from fp.callables import Unary
from fp.effects import Reader, State, run
from std.testing import assert_equal
@fieldwise_init
struct Select(Unary):
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Optional[Int]]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out:
        if value == 2: raise 73
        return Reader[Int].pure(Optional(value))
@fieldwise_init
struct Expand(Unary):
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[List[Int]]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out:
        if value == 2: raise 73
        return Reader[Int].pure(List[Int]([value]))
@fieldwise_init
struct StateSelect(Unary):
    comptime Arg = Int
    comptime Out = State[Int].Pure[Optional[Int]]
    def call(self, var value: Int) -> Self.Out:
        return State[Int].pure(Optional(value) if value % 2 == 0 else Optional[Int]())
@fieldwise_init
struct StateExpand(Unary):
    comptime Arg = Int
    comptime Out = State[Int].Pure[List[Int]]
    def call(self, var value: Int) -> Self.Out: return State[Int].pure(List[Int]([value]))
def abandon():
    _ = iterated(range(4)).traverse_filter(Select())
    _ = iterated(range(4)).flat_traverse(Expand())
def main() raises:
    abandon()
    var environment = 0
    var caught = 0
    var selected = iterated(range(4)).traverse_filter(Select())
    try: _ = run[Reader[Int]](selected^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    caught = 0
    var expanded = iterated(range(4)).flat_traverse(Expand())
    try: _ = run[Reader[Int]](expanded^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    var selected_state = iterated(range(4)).traverse_filter(StateSelect())
    var state_result = run[State[Int]](selected_state^,42)
    assert_equal(state_result[0],[0,2])
    assert_equal(state_result[1],42)
    var expanded_state = iterated(range(3)).flat_traverse(StateExpand())
    var state_flat = run[State[Int]](expanded_state^,43)
    assert_equal(state_flat[0],[0,1,2])
    assert_equal(state_flat[1],43)
