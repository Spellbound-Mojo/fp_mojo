"""Failures that stop their siblings recover as in Cats Effect.

When one element of `par_traverse`, or one side of `both`, fails, the others
are stopped. Their cancellation is expected, as a race loser's is, so the
failure is not marked canceled: `handle_error_with` recovers it and `attempt`
observes it. An element or side that canceled itself still cancels the
result, which no handler recovers. Runs on the selected profile; the stopped
siblings would otherwise sleep for 10 s.
"""
from std.os import abort
from fp.algebra import par_traverse
from fp.effects import EffectFailure, Outcome
from fp.effects.async_runtime import IO, Duration, run


def check(condition: Bool, message: String):
    if not condition:
        abort(String("recover_after_stop: ", message))


def sleeping(var index: Int) -> IO[Int, Int]:
    try:
        return IO[Int, Int].pure(index).delay_by(Duration.seconds(10))
    except:
        return IO[Int, Int].raise_error(-1)


def fails_at_three(var index: Int) -> IO[Int, Int]:
    if index == 3:
        return IO[Int, Int].raise_error(3)
    return sleeping(index)


def zero(var unit: NoneType) -> Int:
    return 0


def cancels_at_three(var index: Int) -> IO[Int, Int]:
    if index == 3:
        return IO[NoneType, Int].canceled().map(zero)
    return sleeping(index)


def recover_list(var failure: EffectFailure[Int]) -> IO[List[Int], Int]:
    var marker = List[Int]()
    marker.append(-failure.errors.first())
    return IO[List[Int], Int].pure(marker^)


def recover_pair(var failure: EffectFailure[Int]) -> IO[Tuple[Int, Int], Int]:
    return IO[Tuple[Int, Int], Int].pure((-failure.errors.first(), 0))


def indices() -> List[Int]:
    return List[Int]([0, 1, 2, 3, 4, 5])


def par_traverse_recovers():
    var outcome = run(par_traverse(indices(), fails_at_three).handle_error_with(recover_list))
    check(Bool(outcome) and outcome.value().is_ok(), "handle_error_with recovers a par_traverse failure")
    var values = outcome.take()._take_ok()
    check(len(values) == 1 and values[0] == -3, "the handler sees the failing element's error")


def par_traverse_attempt():
    var outcome = run(par_traverse(indices(), fails_at_three).attempt())
    check(Bool(outcome) and outcome.value().is_ok(), "attempt observes a par_traverse failure")
    var attempted = outcome.take()._take_ok()
    check(attempted.is_err(), "the attempted traversal failed")
    var failure = attempted^._take_err()
    check(not failure.canceled, "stopping the rest does not mark the failure canceled")
    var errors = failure^.into_errors().into_list()
    check(len(errors) == 1 and errors[0] == 3, "only the failing element's error")


def both_recovers():
    var left = run(IO[Int, Int].raise_error(4).both(sleeping(1)).handle_error_with(recover_pair))
    check(Bool(left) and left.value().is_ok(), "handle_error_with recovers both's left failure")
    check(left.take()._take_ok()[0] == -4, "the handler sees the left side's error")
    var right = run(sleeping(1).both(IO[Int, Int].raise_error(5)).handle_error_with(recover_pair))
    check(Bool(right) and right.value().is_ok(), "handle_error_with recovers both's right failure")
    check(right.take()._take_ok()[0] == -5, "the handler sees the right side's error")


def self_cancellation_still_cancels():
    var traversal = run(par_traverse(indices(), cancels_at_three).handle_error_with(recover_list))
    check(not traversal, "an element that canceled itself cancels the traversal")
    var pair = run(IO[NoneType, Int].canceled().map(zero).both(sleeping(1)).handle_error_with(recover_pair))
    check(not pair, "a side that canceled itself cancels both")


def main():
    par_traverse_recovers()
    par_traverse_attempt()
    both_recovers()
    self_cancellation_still_cancels()
    print("recover_after_stop: par_traverse and both failures recover; self-cancellation still cancels")
