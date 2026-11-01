"""Borrowed chain views retain deferred execution, exact errors and reuse."""
from fp.functions import kleisli
from fp.iteration import iterated
from fp.effects import Reader, State, run
from std.memory import ArcPointer
from std.testing import assert_equal

def main() raises:
    var calls = ArcPointer(0)
    def select(var value: Int) {calls} -> Reader[Int].Pure[Optional[Int]]:
        calls[] += 1
        return Reader[Int].pure(Optional(value) if value % 2 == 0 else Optional[Int]())
    def expand(var value: Int) {calls} -> Reader[Int].Pure[List[Int]]:
        calls[] += 1
        return Reader[Int].pure(List[Int]([value,value*10]))
    var selector = kleisli[Reader[Int]](select)
    var expander = kleisli[Reader[Int]](expand)
    _ = iterated(range(3)).traverse_filter(selector)
    _ = iterated(range(3)).flat_traverse(expander)
    assert_equal(calls[],0)
    var pending = iterated(range(4)).traverse_filter(selector)
    var flat = iterated(range(1,3)).flat_traverse(expander)
    assert_equal(calls[],0)
    var environment = 10
    assert_equal(run[Reader[Int]](pending^,environment),[0,2])
    assert_equal(run[Reader[Int]](flat^,environment),[1,10,2,20])
    assert_equal(calls[],6)
    assert_equal(run[Reader[Int]](selector.call(6),environment).value(),6)
    assert_equal(calls[],7)
    def fail_select(var value: Int) raises Int -> Reader[Int].Pure[Optional[Int]]: raise 73
    def fail_flat(var value: Int) raises Int -> Reader[Int].Pure[List[Int]]: raise 74
    var rejecting = kleisli[Reader[Int]](fail_select)
    var rejecting_flat = kleisli[Reader[Int]](fail_flat)
    var deferred_error = iterated(range(1)).traverse_filter[X=Error](rejecting)
    var deferred_flat_error = iterated(range(1)).flat_traverse[X=Error](rejecting_flat)
    var caught = 0
    try: _ = run[Reader[Int]](deferred_error^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,73)
    caught = 0
    try: _ = run[Reader[Int]](deferred_flat_error^,environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,74)
    def select_state(var value: Int) -> State[Int].Pure[Optional[Int]]: return State[Int].pure(Optional(value))
    def flat_state(var value: Int) -> State[Int].Pure[List[Int]]: return State[Int].pure(List[Int]([value]))
    var state_selector = kleisli[State[Int]](select_state)
    var state_expander = kleisli[State[Int]](flat_state)
    var state_pending = iterated(range(3)).traverse_filter(state_selector)
    var state_flat = iterated(range(3)).flat_traverse(state_expander)
    var selected = run[State[Int]](state_pending^,42)
    var flattened = run[State[Int]](state_flat^,43)
    assert_equal(selected[0],[0,1,2])
    assert_equal(flattened[0],[0,1,2])
    assert_equal(selected[1],42)
    assert_equal(flattened[1],43)
