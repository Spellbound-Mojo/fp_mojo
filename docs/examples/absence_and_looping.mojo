from fp.algebra import IdentityFamily, OptionalFamily, or_else_absent, get_or_else_effect, tail_rec_m
from fp.effects import State, run
from fp.data import ControlFlow, Break, Continue
from std.testing import assert_equal

def fallback_name() -> Optional[String]:
    return Optional(String("guest"))

def default_count() -> State[Int].Pure[Int]:
    return State[Int].pure(10)

def count_step(var count: Int) -> Optional[ControlFlow[Int, Int]]:
    if count == 100000:
        return Optional(ControlFlow[Int, Int](Break(count)))
    return Optional(ControlFlow[Int, Int](Continue(count + 1)))

def main() raises:
    var name = or_else_absent[IdentityFamily](fallback_name, Optional[String]())
    print("name:", name.value())
    var count = get_or_else_effect[State[Int]](default_count, State[Int].pure(Optional[Int]()))
    var result = run[State[Int]](count^, 7)
    assert_equal(result, (10, 7))
    print("count:", result[0], "state:", result[1])
    var completed = tail_rec_m[OptionalFamily](count_step, 0)
    assert_equal(completed.value(), 100000)
    print("loop:", completed.value())
