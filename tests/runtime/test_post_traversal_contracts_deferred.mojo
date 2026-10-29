"""Public postprocessing metadata keeps construction and execution errors distinct."""
from algebra_support.post_traversal_contracts import selected, flattened
from algebra_support.filter_effect_contracts import FailingCompaction
from fp.algebra import ListFamily, OptionalFamily
from fp.callables import Unary, as_unary
from fp.effects import Reader, State, run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ObserveSelect[fail_at: Int = -1](Unary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Optional[Int]]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out:
        self.calls[] += 1
        if value == Self.fail_at: raise 73
        return Reader[Int].pure(Optional(value) if value % 2 == 0 else Optional[Int]())

@fieldwise_init
struct ObserveFlat[fail_at: Int = -1](Unary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[List[Int]]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out:
        self.calls[] += 1
        if value == Self.fail_at: raise 73
        return Reader[Int].pure(List[Int]([value,value*10]))

def abandon(calls: ArcPointer[Int]):
    _ = selected[ListFamily,Reader[Int]](range(3),ObserveSelect(calls))
    _ = flattened[ListFamily,Reader[Int]](range(3),ObserveFlat(calls))

def main() raises:
    var calls = ArcPointer(0)
    abandon(calls)
    assert_equal(calls[],0)
    var environment = 10
    var pending = selected[ListFamily,Reader[Int]](range(4),ObserveSelect(calls))
    assert_equal(calls[],0)
    assert_equal(run[Reader[Int]](pending^,environment),[0,2])
    assert_equal(calls[],4)
    var flat = flattened[ListFamily,Reader[Int]](range(1,3),ObserveFlat(calls))
    assert_equal(calls[],4)
    assert_equal(run[Reader[Int]](flat^,environment),[1,10,2,20])
    assert_equal(calls[],6)
    var caught = 0
    var failed = selected[ListFamily,Reader[Int]](range(4),ObserveSelect[2](calls))
    try: _ = run[Reader[Int]](failed^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    var failed_flat = flattened[ListFamily,Reader[Int]](range(4),ObserveFlat[2](calls))
    caught = 0
    try: _ = run[Reader[Int]](failed_flat^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    # Optional invokes its callback at construction, unlike List into Reader.
    caught = 0
    try: _ = selected[OptionalFamily,Reader[Int]](Optional(2),ObserveSelect[2](calls))
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    var finish = selected[FailingCompaction,Reader[Int]](range(2),ObserveSelect(calls))
    caught = 0
    try: _ = run[Reader[Int]](finish^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,83)
    def select_state(var value: Int) -> State[Int].Pure[Optional[Int]]:
        return State[Int].pure(Optional(value))
    def flat_state(var value: Int) -> State[Int].Pure[List[Int]]:
        return State[Int].pure(List[Int]([value]))
    var state = selected[ListFamily,State[Int]](range(3),as_unary(select_state))
    var state_result = run[State[Int]](state^,42)
    assert_equal(state_result[0],[0,1,2])
    assert_equal(state_result[1],42)
    var flat_state_result = flattened[ListFamily,State[Int]](range(3),as_unary(flat_state))
    var state_flat = run[State[Int]](flat_state_result^,43)
    assert_equal(state_flat[0],[0,1,2])
    assert_equal(state_flat[1],43)
