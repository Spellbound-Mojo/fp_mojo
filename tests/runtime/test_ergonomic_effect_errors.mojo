"""Native error channels and state changes survive the new convenience entries."""
from fp.callables import Unary, BorrowCallable
from fp.algebra import IdentityFamily, ResultFamily, tail_rec_m, get_or_else_effect, or_else_absent
from fp.effects import State, Reader, asks, inspect, run, action
from fp.data import ControlFlow, Continue, Break, Result, Err
from std.testing import assert_equal, assert_true

@fieldwise_init
struct ErgonomicError(Movable):
    var code: Int

comptime EffectLoopControl = ControlFlow[Int, Int]

@fieldwise_init
struct StateLoopEndpoint(Unary):
    var current: Int
    comptime Arg = Int
    comptime Out = Tuple[EffectLoopControl, Int]
    def call(self, var state: Int) -> Self.Out:
        if self.current == 10:
            return (EffectLoopControl(Break(self.current)), state + 1)
        return (EffectLoopControl(Continue(self.current + 1)), state + 1)

def stateful_loop_step(var current: Int) -> State[Int].Endpoint[EffectLoopControl, StateLoopEndpoint]:
    return action[State[Int], EffectLoopControl](StateLoopEndpoint(current))

@fieldwise_init
struct ReadLoopLimit(BorrowCallable):
    var current: Int
    comptime Payload = Int
    comptime Result = EffectLoopControl
    def invoke(self, ref limit: Int) -> Self.Result:
        if self.current == limit:
            return Break(self.current)
        return Continue(self.current + 1)

def reader_loop_step(var current: Int) -> Reader[Int].Projected[ReadLoopLimit]:
    return asks[Reader[Int]](ReadLoopLimit(current))

def failing_loop_step(var current: Int) raises ErgonomicError -> EffectLoopControl:
    if current == 3:
        raise ErgonomicError(current)
    return Continue(current + 1)

def failed_projection(value: Int) raises ErgonomicError -> Int:
    raise ErgonomicError(value)

def failed_default() raises ErgonomicError -> Int:
    raise ErgonomicError(7)

def failed_result_default() -> Result[Int, String]: return Err(String("missing"))

def main() raises:
    var state_program = tail_rec_m[State[Int]](0, stateful_loop_step)
    assert_equal(run[State[Int]](state_program^, 20), (10, 31))
    var limit = 2000
    var reader_program = tail_rec_m[Reader[Int]](0, reader_loop_step)
    assert_equal(run[Reader[Int]](reader_program^, limit), 2000)
    var seen = 0
    try:
        _ = tail_rec_m[IdentityFamily](0, failing_loop_step)
    except error:
        seen = error.code
    assert_equal(seen, 3)
    var project = asks[Reader[Int]](failed_projection)
    try:
        _ = run[Reader[Int]](project^, limit)
    except error:
        seen = error.code
    assert_equal(seen, 2000)
    var state_project = inspect[State[Int]](failed_projection)
    try:
        _ = run[State[Int]](state_project^, 12)
    except error:
        seen = error.code
    assert_equal(seen, 12)
    try:
        _ = get_or_else_effect[IdentityFamily](failed_default, Optional[Int]())
    except error:
        seen = error.code
    assert_equal(seen, 7)
    var present = 0
    try:
        present = get_or_else_effect[IdentityFamily](failed_default, Optional(42))
    except:
        pass
    assert_equal(present, 42)
    var failed = get_or_else_effect[ResultFamily[String]](failed_result_default, ResultFamily[String].pure(Optional[Int]()))
    assert_true(failed.is_err())
