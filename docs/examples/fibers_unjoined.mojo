"""A failure nobody joins goes to the runtime's reporter, once."""
from fp.callables import OnceUnary
from fp.effects import EffectFailure, Outcome, fold_outcome
from fp.effects.async_runtime import IO, IORuntimeConfig, Deferred, Fiber, run
from std.testing import assert_equal


def show_value(var value: Int) -> String:
    return String("ok ", value)


def show_failure(var failure: EffectFailure[String]) -> String:
    return String("failed '", failure.errors.first(), "'")


def show_canceled() -> String:
    return "canceled"


def describe(var outcome: Outcome[Int, String]) -> String:
    return fold_outcome(outcome^, show_value, show_failure, show_canceled)


def print_report(line: String):
    print("reporter:", line)


def discard(var won: Bool) -> NoneType:
    return None


def failing_child(failed: Deferred[Int]) -> IO[Int, String]:
    # The finalizer runs after the body has failed and completes `failed`.
    var failure = IO[Int, String].raise_error("disk full")
    return failure^.guarantee(failed.complete[String](1).map(discard))


@fieldwise_init
struct DropAfterFailure(OnceUnary):
    """Wait until the child has failed, then end without joining it."""
    var failed: Deferred[Int]
    comptime Arg = Fiber[Int, String]
    comptime Out = IO[Int, String]

    def call_once(deinit self, var fiber: Fiber[Int, String]) -> IO[Int, String]:
        _ = fiber^
        return self.failed.get[String]()


def main() raises:
    var config = IORuntimeConfig()
    config.reporter = print_report
    var failed = Deferred[Int]()
    var program = failing_child(failed).start().flat_map(DropAfterFailure(failed^))
    var owner = describe(run(program^, config))
    assert_equal(owner, "ok 1")
    print("owner:", owner)
