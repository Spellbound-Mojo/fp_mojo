"""Borrowed views retain deferred source pulls, errors, and callback reuse."""
from fp.functions import kleisli
from fp.iteration import iterated
from fp.effects import Reader, State, ResultT, run
from fp.data import Result, Ok, Err
from algebra_support.arrows import Produce
from algebra_support.iterators import Counted
from std.memory import ArcPointer
from std.testing import assert_equal


def main() raises:
    var calls = ArcPointer(0)
    var reader = kleisli[Reader[Int]](Produce[False](calls))
    var state = kleisli[State[Int]](Produce[True](calls))
    var environment = 10
    _ = iterated(range(3)).traverse(reader)
    _ = iterated(range(3)).traverse_void(state)
    assert_equal(calls[], 0)
    for count in [0, 3]:
        var pulls = 0
        calls[] = 0
        var collected = iterated(Counted(Pointer(to=pulls), 0, count)).traverse(reader)
        assert_equal(pulls, 0)
        assert_equal(calls[], 0)
        assert_equal(run[Reader[Int]](collected^, environment), List[Int]() if count == 0 else [11, 12, 13])
        assert_equal(pulls, count + 1)
        assert_equal(calls[], count)
        pulls = 0
        calls[] = 0
        var discarded = iterated(Counted(Pointer(to=pulls), 0, count)).traverse_void(reader)
        assert_equal(pulls, 0)
        assert_equal(calls[], 0)
        _ = run[Reader[Int]](discarded^, environment)
        assert_equal(pulls, count + 1)
        assert_equal(calls[], count)
        calls[] = 0
        var pending = iterated(range(count)).traverse(state)
        assert_equal(calls[], 0)
        var result = run[State[Int]](pending^, 10)
        assert_equal(result[0], List[Int]() if count == 0 else [10, 11, 13])
        assert_equal(result[1], 10 if count == 0 else 13)
        calls[] = 0
        var pending_void = iterated(range(count)).traverse_void(state)
        assert_equal(calls[], 0)
        var final_state = run[State[Int]](pending_void^, 10)
        assert_equal(final_state[1], 10 if count == 0 else 13)
        assert_equal(calls[], count)
    assert_equal(run[Reader[Int]](reader.call(4), environment), 14)
    def fail(var value: Int) raises Int -> Reader[Int].Pure[Int]: raise 73
    var failing = kleisli[Reader[Int]](fail)
    var pending = iterated(range(1)).traverse(failing)
    var pending_void = iterated(range(1)).traverse_void[X=Error](failing)
    var caught = 0
    try: _ = run[Reader[Int]](pending^, environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 73)
    # A ResultT layer shares Reader storage but must keep fail-fast semantics.
    comptime Checked = ResultT[Reader[Int], String]
    def checked(var value: Int) -> Checked.Pure[Int]:
        if value == 2:
            return Reader[Int].pure(Result[Int, String](Err(String("stop"))))
        return Checked.pure(value)
    var layered = kleisli[Checked](checked)
    var pulls = 0
    var collected = iterated(Counted(Pointer(to=pulls), 0, 5)).traverse(layered)
    assert_equal(pulls, 0)
    var outcome = run[Reader[Int]](collected^, environment)
    comptime assert type_of(outcome) == Result[List[Int], String]
    assert_equal(pulls, 2)
    assert_equal(outcome^.swap().to_optional().value(), "stop")
    pulls = 0
    var discarded = iterated(Counted(Pointer(to=pulls), 0, 5)).traverse_void(layered)
    assert_equal(pulls, 0)
    var void_outcome = run[Reader[Int]](discarded^, environment)
    comptime assert type_of(void_outcome) == Result[NoneType, String]
    assert_equal(pulls, 2)
    assert_equal(void_outcome^.swap().to_optional().value(), "stop")
    var empty = run[Reader[Int]](iterated(range(0)).traverse(layered), environment)
    assert_equal(empty^.raise_on_err(), List[Int]())
    assert_equal(run[Reader[Int]](layered.call(3), environment).raise_on_err(), 3)
    caught = 0
    try: _ = run[Reader[Int]](pending_void^, environment)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 73)
