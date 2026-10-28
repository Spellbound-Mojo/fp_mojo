"""Deep effectful loops preserve stopping, error and deferred behavior."""
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, tail_rec_m
from fp.data import ControlFlow, Break, Continue
from fp.effects import Reader, State, run
from std.testing import assert_equal, assert_false

comptime LoopControl = ControlFlow[Int, Int]

def deep_step(var value: Int) -> LoopControl:
    if value == 100000:
        return Break(value)
    return Continue(value + 1)

def optional_step(var value: Int) -> Optional[LoopControl]:
    if value == 5:
        return None
    return Optional(LoopControl(Continue(value + 1)))

def reader_step(var value: Int) -> Reader[Int].Pure[LoopControl]:
    return Reader[Int].pure(deep_step(value))

def state_step(var value: Int) -> State[Int].Pure[LoopControl]:
    return State[Int].pure(deep_step(value))

def branching_step(var value: Int) -> List[LoopControl]:
    if value == 0:
        return [LoopControl(Continue(1)), LoopControl(Break(3))]
    return [LoopControl(Break(value)), LoopControl(Break(value + 1))]

def main() raises:
    assert_equal(tail_rec_m[IdentityFamily](deep_step, 0), 100000)
    assert_false(tail_rec_m[OptionalFamily](optional_step, 0))
    assert_equal(tail_rec_m[ListFamily](branching_step, 0), [1, 2, 3])
    var program = tail_rec_m[Reader[Int]](reader_step, 0)
    var env = 4
    assert_equal(run[Reader[Int]](program^, env), 100000)
    var state_program = tail_rec_m[State[Int]](state_step, 0)
    assert_equal(run[State[Int]](state_program^, 9), (100000, 9))
