"""Completed outcome inspection preserves complete failure and selected errors."""
from fp.effects import fold_outcome, EffectFailure
from fp.effects._async.kernel import run
from recovery_support import source
from foundation import check


def success(value: Int) -> Int:
    return value


def failure(var error: EffectFailure[Int]) -> Int:
    var canceled = error.canceled
    var errors = error^.into_errors().into_list()
    return errors[0] + errors[1] + (100 if canceled else 0)


def canceled() -> Int:
    return -1


def raising(value: Int) raises Int -> Int:
    raise value + 1


def main():
    check(fold_outcome(run(source(0)), success, failure, canceled) == 42, "fold success")
    check(fold_outcome(run(source(1)), success, failure, canceled) == -1, "fold cancellation-only")
    check(fold_outcome(run(source(2)), success, failure, canceled) == 33, "fold complete failure")
    check(fold_outcome(run(source(3)), success, failure, canceled) == 133, "failure plus cancellation still selects failure")
    var seen = 0
    try:
        _ = fold_outcome(run(source(0)), raising, failure, canceled)
    except error:
        comptime assert type_of(error) == Int
        seen = error
    check(seen == 43, "fold preserves the callback's exact native error")
    print("outcome fold: selected native callback, complete errors, cancellation flag, exact raised error")
