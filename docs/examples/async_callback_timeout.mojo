"""Drive a callback timeout with deterministic time and owned withdrawal."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import CancellationToken, EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, Completion, Clock, Duration, Driver


@fieldwise_init
struct Register(OnceUnary):
    """Keep the completion for an external producer; the IO owns this state."""
    var saved: ArcPointer[Optional[Completion[Int, Int]]]
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType
    def call_once(deinit self, var done: Completion[Int, Int]) -> NoneType:
        self.saved[] = Optional(done^)
        return None


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
    var source = IO[Int, Int].async(Register(saved.copy()), IO[NoneType, Int].delay(withdrawn))
    var driver = Driver(source^.timeout_to(duration, IO[Int, Int].pure(-1)), CancellationToken(), clock)
    var pending = driver.poll()
    try:
        clock.advance_to(pending.deadline.value())
    except error:
        abort("expected a valid manual deadline")
    while not driver.poll().completed:
        pass
    print(fold_outcome(driver^.finish(), success, failure, canceled))
