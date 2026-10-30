"""Request cancellation and retain the root until all cleanup finishes."""
from fp.effects import CancellationToken, EffectFailure, fold_outcome
from fp.effects.async_runtime import Clock, Driver, Duration, delay, guarantee, sleep


def cleanup() -> NoneType:
    print("released")
    return None


def success(value: NoneType) -> Int:
    return 1


def failure(var errors: EffectFailure[Int]) -> Int:
    return -1


def canceled() -> Int:
    return 0


def main() raises:
    var clock = Clock.manual()
    var span = Duration.seconds(30)
    var driver = Driver(guarantee(sleep[Int](span), delay[Int](cleanup)), CancellationToken(), clock)
    _ = driver.poll()
    driver.request_cancel()
    while not driver.poll().completed:
        pass
    print("canceled:", fold_outcome(driver^.finish(), success, failure, canceled) == 0)
