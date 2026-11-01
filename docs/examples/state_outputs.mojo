"""Choose the output needed from State without unpacking its run tuple."""
from fp.effects import State, StateT, inspect, modify
from fp.algebra import OptionalFamily
from fp.functions import pipeline
from std.testing import assert_equal


def ticket(counter: Int) -> String: return "ticket " + String(counter)
def increment(counter: Int) -> Int: return counter + 1


def main() raises:
    var label = pipeline(inspect[State[Int]](ticket)).run_value(10)
    assert_equal(label,"ticket 10")
    print("value:",label)

    var next_counter = pipeline(modify[State[Int]](increment)).run_state(10)
    assert_equal(next_counter,11)
    print("final state:",next_counter)

    comptime MaybeState = StateT[OptionalFamily,Int]
    var maybe_label = pipeline(inspect[MaybeState](ticket)).run_value(12)
    assert_equal(maybe_label.value(),"ticket 12")
    print("optional value:",maybe_label.value())

    var absent = pipeline(MaybeState.lift(Optional[String]())).run_state(12)
    assert_equal(Bool(absent),False)
    print("state present:",Bool(absent))
