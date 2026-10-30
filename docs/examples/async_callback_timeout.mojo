"""Drive a callback timeout with deterministic time and owned withdrawal."""
from std.memory import ArcPointer
from std.os import abort
from fp.effects import CancellationToken, EffectFailure, fold_outcome
from fp.effects.async_runtime import Completion, Clock, Duration, Driver, callback, delay, pure, timeout_to


def withdrawn() -> NoneType:
    print("withdrawn")
    return None


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main() raises:
    var clock = Clock.manual()
    var duration = Duration.milliseconds(5)
    var saved = ArcPointer(Optional[Completion[Int, Int]]())
    def register(done: Completion[Int, Int]) {saved}:
        saved[] = Optional(done.copy())
    var source = callback(register, delay[Int](withdrawn))
    var driver = Driver(timeout_to(source^, duration, pure[Int](-1)), CancellationToken(), clock)
    var pending = driver.poll()
    try:
        clock.advance_to(pending.deadline.value())
    except error:
        abort("expected a valid manual deadline")
    while not driver.poll().completed:
        pass
    print(fold_outcome(driver^.finish(), success, failure, canceled))
