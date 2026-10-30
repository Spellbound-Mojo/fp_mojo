"""Single-step test driving through the public host: transitions, quiescence and manual time."""
from std.os import abort
from fp.effects import CancellationToken, EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, Driver, Clock, Duration, Deferred, IORuntimeConfig, Progress, run
from fp.effects.async_runtime.protocols import Machine


def twice(var value: Int) -> Int:
    return value * 2


def next(var value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value + 1)


def ten(var unit: NoneType) -> Int:
    return 10


def success(value: Int) -> Int:
    return value


def add(var pair: Tuple[Int, Int]) -> Int:
    return pair[0] + pair[1]


def failure(var errors: EffectFailure[Int]) -> Int:
    return -1


def canceled() -> Int:
    return -2


def step[P: Machine](mut driver: Driver[P], budget: Int) -> Progress:
    """Poll without raising, so a live non-Deinitable driver is never abandoned."""
    try:
        return driver.poll(budget)
    except:
        abort("a nonnegative budget is accepted")


def stepping() raises:
    var config = IORuntimeConfig(1, 1)
    var driver = Driver(IO[Int, Int].pure(20).map(twice).flat_map(next).map(twice), CancellationToken(), Clock(), config)
    var steps = 0
    while True:
        var progress = step(driver, 1)
        check(progress.transitions <= 1, "a threshold of one runs one transition per root poll")
        steps += progress.transitions
        if progress.completed:
            break
        check(progress.runnable and not progress.quiescent, "a stepped program stays runnable")
    check(fold_outcome(driver^.finish(), success, failure, canceled) == 82, "stepping computes the same result")
    check(steps >= 5, "each head and frame took its own step")


def nested_stepping() raises:
    var config = IORuntimeConfig(1, 1)
    var left = IO[Int, Int].pure(1).map(twice).flat_map(next)
    var right = IO[Int, Int].pure(10).flat_map(next).map(twice)
    var driver = Driver(left^.both(right^).map(add), CancellationToken(), Clock(), config)
    var polls = 0
    while True:
        var progress = step(driver, 1)
        check(progress.transitions <= 1, "nested run loops share the one transition")
        polls += 1
        if progress.completed:
            break
        check(polls < 1_000, "nested IO inside a leaf progresses at a threshold of one")
    check(fold_outcome(driver^.finish(), success, failure, canceled) == 25, "stepping nested IO computes the same result")


def quiescence() raises:
    var cell = Deferred[Int]()
    var driver = Driver(cell.get[Int](), CancellationToken(), Clock(), IORuntimeConfig())
    var waiting = step(driver, 8)
    check(not waiting.completed and not waiting.runnable and waiting.quiescent, "a parked read awaits external input")
    driver.request_cancel()
    while not step(driver, 8).completed:
        pass
    check(fold_outcome(driver^.finish(), success, failure, canceled) == -2, "cancellation ends the wait")


def manual_time() raises:
    var clock = Clock.manual()
    var driver = Driver(IO[NoneType, Int].sleep(Duration.milliseconds(5)).map(ten), CancellationToken(), clock, IORuntimeConfig())
    var sleeping = step(driver, 8)
    check(not sleeping.completed and not sleeping.quiescent and Bool(sleeping.deadline), "a timer is not quiescent")
    try:
        clock.advance_to(sleeping.deadline.value())
    except:
        abort("a manual clock advances to a later deadline")
    while True:
        var progress = step(driver, 8)
        if progress.completed:
            check(not progress.quiescent, "completion is not quiescence")
            break
    check(fold_outcome(driver^.finish(), success, failure, canceled) == 10, "virtual time completes the sleep")


def configured_run() raises:
    var config = IORuntimeConfig(1, 1)
    var program = IO[Int, Int].pure(20).map(twice).flat_map(next)
    check(fold_outcome(run(program^, config), success, failure, canceled) == 41, "run takes a configuration")
    var token = CancellationToken()
    token.cancel()
    var stopped = IO[Int, Int].pure(20).flat_map(next)
    check(fold_outcome(run(stopped^, token, config), success, failure, canceled) == -2, "run takes a token and a configuration")


def main() raises:
    stepping()
    nested_stepping()
    quiescence()
    manual_time()
    configured_run()
    print("io stepping: one transition per poll, nested stepping, quiescence, manual time, configured run")


def check(condition: Bool, message: String):
    if not condition:
        abort(message)
