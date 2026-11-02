"""Bound a program with a timeout: keep its result, fall back, or fail."""
from fp.effects import EffectFailure, Outcome, fold_outcome
from fp.effects.async_runtime import IO, Duration, run
from std.testing import assert_equal


def show_value(var value: Int) -> String:
    return String("ok ", value)


def show_failure(var failure: EffectFailure[String]) -> String:
    return String("failed '", failure.errors.first(), "'")


def show_canceled() -> String:
    return "canceled"


def describe(var outcome: Outcome[Int, String]) -> String:
    return fold_outcome(outcome^, show_value, show_failure, show_canceled)


def main() raises:
    var limit = Duration.milliseconds(20)

    # The source finishes long before the deadline and keeps its value.
    var quick = IO[Int, String].pure(7).timeout_to(limit, IO[Int, String].pure(-1))
    var kept = describe(run(quick^))
    assert_equal(kept, "ok 7")
    print("quick source:", kept)

    # The source never finishes: it is canceled at the deadline, then the fallback runs.
    var stuck = IO[Int, String].never().timeout_to(limit, IO[Int, String].pure(-1))
    var fallback = describe(run(stuck^))
    assert_equal(fallback, "ok -1")
    print("stuck source:", fallback)

    # timeout fails with the given error instead of running a fallback.
    var bounded = IO[Int, String].never().timeout(limit, "lookup timed out")
    var failed = describe(run(bounded^))
    assert_equal(failed, "failed 'lookup timed out'")
    print("stuck source:", failed)
