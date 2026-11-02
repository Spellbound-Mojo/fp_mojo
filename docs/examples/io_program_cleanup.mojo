"""Run cleanup after success, failure and cancellation with guarantee and on_cancel."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, run
from std.testing import assert_equal


def write_lines() -> Int:
    print("write lines")
    return 3


def reject(lines: Int) -> IO[Int, String]:
    return IO[Int, String].raise_error("disk full")


def stop_after(unit: NoneType) -> Int:
    print("not reached")
    return 0


def close_report():
    print("close report")


def note_cancel():
    print("note cancellation")


def protected(var body: IO[Int, String]) -> IO[Int, String]:
    var closed = body^.guarantee(IO[NoneType, String].delay(close_report))
    return closed^.on_cancel(IO[NoneType, String].delay(note_cancel))


def describe(value: Int) -> String:
    return String("success: ", value)


def describe_failure(var failure: EffectFailure[String]) -> String:
    var canceled = failure.canceled
    var text = String("failure:")
    for error in failure^.into_errors():
        text += String(" [", error, "]")
    return String(text, " canceled: ", canceled)


def describe_cancel() -> String:
    return "canceled"


def report(var program: IO[Int, String]) -> String:
    return fold_outcome(run(program^), describe, describe_failure, describe_cancel)


def main() raises:
    var written = report(protected(IO[Int, String].delay(write_lines)))
    assert_equal(written, "success: 3")
    print(written)

    var rejected = report(protected(IO[Int, String].delay(write_lines).flat_map(reject)))
    assert_equal(rejected, "failure: [disk full] canceled: False")
    print(rejected)

    var stopped = report(protected(IO[NoneType, String].canceled().map(stop_after)))
    assert_equal(stopped, "canceled")
    print(stopped)

    var close_failed = IO[NoneType, String].raise_error("close failed")
    var both_failed = report(IO[Int, String].delay(write_lines).flat_map(reject).guarantee(close_failed^))
    assert_equal(both_failed, "failure: [disk full] [close failed] canceled: False")
    print(both_failed)

    var close_failed_again = IO[NoneType, String].raise_error("close failed")
    var canceled_then_failed = report(IO[NoneType, String].canceled().map(stop_after).guarantee(close_failed_again^))
    assert_equal(canceled_then_failed, "failure: [close failed] canceled: True")
    print(canceled_then_failed)
